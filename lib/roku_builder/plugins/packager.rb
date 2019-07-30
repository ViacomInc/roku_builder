# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class Packager < Util
    extend Plugin

    def self.commands
      {
        package: {device: true, source: true, stage: true, exclude: true},
        genkey: {device: true},
        key: {device: true, source: true}
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("-p", "--package", "Package an app") do
        options[:package] = true
      end
      parser.on("-k", "--key", "Change device key") do
        options[:key] = true
      end
      parser.on("--genkey", "Generate a new key") do
        options[:genkey] = true
      end
      parser.separator "Options:"
      parser.on("--inspect-package", "Inspect package after packaging") do
        options[:inspect_package] = true
      end
    end

    def self.dependencies
      [Loader, Inspector]
    end

    def package(options:)
      check_options(options)
      #sideload
      loader = Loader.new(config: @config)
      loader.sideload(options: options)
      loader.squash(options: options) if @config.stage[:squash]
      #rekey
      key(options: options)
      #package
      sign_package(app_name_version: "", password: @config.key[:password], stage: options[:stage])
      #inspect
      if options[:inspect_package]
        @config.in = @config.out
        options[:password] = @config.key[:password]
        Inspector.new(config: @config).inspect(options: options)
      end
    end

    def genkey(options:)
      password, dev_id = generate_new_key()
      @logger.unknown("Password: "+password)
      @logger.info("DevID: "+dev_id)

      out = @config.out
      out[:file] ||= "key_"+dev_id+".pkg"
      @config.out = out

      Dir.mktmpdir { |dir|
        config_copy = @config.dup
        config_copy.root_dir = dir
        Manifest.generate({config: config_copy, attributes: {}})
        Dir.mkdir(File.join(dir, "source"))
        File.open(File.join(dir, "source", "main.brs"), "w") do |io|
          io.puts "sub main()"
          io.puts "  print \"Load\""
          io.puts "end sub"
        end
        loader = Loader.new(config: config_copy)
        options[:current] = true
        loader.sideload(options: options)
        sign_package(app_name_version: "key_"+dev_id, password: password, stage: options[:stage])
        @logger.unknown("Keyed PKG: #{File.join(@config.out[:folder], @config.out[:file])}")
      }
    end

    # Sets the key on the roku device
    # @param keyed_pkg [String] Path for a package signed with the desired key
    # @param password [String] Password for the package
    # @return [Boolean] True if key changed, false otherwise
    def key(options:)
      oldId = dev_id

      raise ExecutionError, "Missing Key Config" unless @config.key

      # upload new key with password
      payload =  {
        mysubmit: "Rekey",
        passwd: @config.key[:password],
        archive: Faraday::UploadIO.new(@config.key[:keyed_pkg], 'application/octet-stream')
      }
      multipart_connection.post "/plugin_inspect", payload

      # check key
      newId = dev_id
      @logger.info("Key did not change") unless newId != oldId
      @logger.debug(oldId + " -> " + newId)
    end

    # Get the current dev id
    # @return [String] The current dev id
    def dev_id
      path = "/plugin_package"
      conn = simple_connection
      response = conn.get path

      dev_id = /Your Dev ID:\s*<font[^>]*>([^<]*)<\/font>/.match(response.body)
      dev_id ||= /Your Dev ID:[^>]*<\/label> ([^<]*)/.match(response.body)
      dev_id = dev_id[1] if dev_id
      dev_id ||= "none"
      dev_id
    end

    private

    def check_options(options)
      raise InvalidOptions, "Can not use '--in' for packaging" if options[:in]
      raise InvalidOptions, "Can not use '--ref' for packaging" if options[:ref]
      raise InvalidOptions, "Can not use '--current' for packaging" if options[:current]
    end

    # Sign and download the currently sideloaded app
    def sign_package(app_name_version:, password:, stage: nil)
      payload =  {
        mysubmit: "Package",
        app_name: app_name_version,
        passwd: password,
        pkg_time: Time.now.to_i
      }
      response = multipart_connection.post "/plugin_package", payload

      # Check for error
      failed = /(Failed: [^\.]*\.)/.match(response.body)
      raise ExecutionError, failed[1] if failed

      # Download signed package
      pkg = /<a href="pkgs[^>]*>([^<]*)</.match(response.body)[1]
      path = "/pkgs/#{pkg}"
      conn = Faraday.new(url: @url) do |f|
        f.request :digest, @dev_username, @dev_password
        f.adapter Faraday.default_adapter
      end
      response = conn.get path
      raise ExecutionError, "Failed to download signed package" if response.status != 200
      out_file = nil
      unless @config.out[:file]
        out = @config.out
        build_version = Manifest.new(config: @config).build_version
        if stage
          out[:file] = "#{@config.project[:app_name]}_#{stage}_#{build_version}"
        else
          out[:file] = "#{@config.project[:app_name]}_working_#{build_version}"
        end
        @config.out = out
      end
      out_file = File.join(@config.out[:folder], @config.out[:file])
      out_file = out_file+".pkg" unless out_file.end_with?(".pkg")
      File.open(out_file, 'w+b') {|fp| fp.write(response.body)}
      if File.exist?(out_file)
        pkg_size = File.size(out_file).to_f / 2**20
        raise ExecutionError, "PKG file size is too large (#{pkg_size.round(2)} MB): #{out_file}" if pkg_size > 4.0
        @logger.info("Outfile: #{out_file}")
      else
        @logger.warn("Outfile Missing: #{out_file}")
      end
    end

    # Uses the device to generate a new signing key
    #  @return [Array<String>] Password and dev_id for the new key
    def generate_new_key()
      telnet_config = {
        'Host' => @roku_ip_address,
        'Port' => 8080
      }
      connection = Net::Telnet.new(telnet_config)
      connection.puts("genkey")
      waitfor_config = {
        'Match' => /./,
        'Timeout' => false
      }
      password = nil
      dev_id = nil
      while password.nil? or dev_id.nil?
        connection.waitfor(waitfor_config) do |txt|
          while line = txt.slice!(/^.*\n/) do
            words = line.split
            if words[0] == "Password:"
              password = words[1]
            elsif words[0] == "DevID:"
              dev_id = words[1]
            end
          end
        end
      end
      connection.close
      return password, dev_id
    end
  end
  RokuBuilder.register_plugin(Packager)
end
