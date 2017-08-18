# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Collects information on a package for submission
  class Inspector < Util
    extend Plugin

    def self.commands
      {
        inspect: {device: true, source: true},
        screencapture: {device: true}
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("--inspect", "Print out information about a packaged app") do
        options[:inspect] = true
      end
      parser.on("-S", "--screencapture", "Save a screencapture to the output file/folder") do
        options[:screencapture] = true
      end
      parser.separator "Options:"
      parser.on("--password PASSWORD", "Password used for inspect") do |p|
        options[:password] = p
      end
    end

    # Inspects the given pkg
    def inspect(options:)
      pkg = File.join(@config.in[:folder], @config.in[:file])
      pkg = pkg+".pkg" unless pkg.end_with?(".pkg")
      # upload new key with password
      path = "/plugin_inspect"
      conn = multipart_connection
      payload =  {
        mysubmit: "Inspect",
        passwd: options[:password],
        archive: Faraday::UploadIO.new(pkg, 'application/octet-stream')
      }
      response = conn.post path, payload

      app_name = /App Name:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)
      dev_id = nil
      creation_date = nil
      dev_zip = nil
      if app_name
        app_name = app_name[1]
        dev_id = /Dev ID:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)[1]
        creation_date = /new Date\(([^)]*)\)/.match(response.body.delete("\n"))[1]
        dev_zip = /dev.zip:\s*<\/td>\s*<td>\s*<font[^>]*>([^<]*)<\/font>\s*<\/td>/.match(response.body)[1]
      else
        app_name = /App Name:[^<]*<div[^>]*>([^<]*)<\/div>/.match(response.body)[1]
        dev_id = /Dev ID:[^<]*<div[^>]*><font[^>]*>([^<]*)<\/font><\/div>/.match(response.body)[1]
        creation_date = /new Date\(([^\/]*)\)/.match(response.body.delete("\n"))[1]
        dev_zip = /dev.zip:[^<]*<div[^>]*><font[^>]*>([^<]*)<\/font><\/div>/.match(response.body)[1]
      end

      info = {app_name: app_name, dev_id: dev_id, creation_date: Time.at(creation_date.to_i).to_s, dev_zip: dev_zip}

      inspect_logger = ::Logger.new(STDOUT)
      inspect_logger.formatter = proc {|_severity, _datetime, _progname, msg|
        "%s\n\r" % [msg]
      }
      inspect_logger.unknown "=============================================================="
      inspect_logger.unknown "App Name: #{info[:app_name]}"
      inspect_logger.unknown "Dev ID: #{info[:dev_id]}"
      inspect_logger.unknown "Creation Date: #{info[:creation_date]}"
      inspect_logger.unknown "dev.zip: #{info[:dev_zip]}"
      inspect_logger.unknown "=============================================================="

    end

    # Capture a screencapture for the currently sideloaded app
    # @return [Boolean] Success
    def screencapture(options:)
      out = @config.out
      payload =  {
        mysubmit: "Screenshot",
        passwd: @dev_password,
        archive: Faraday::UploadIO.new(File::NULL, 'application/octet-stream')
      }
      response = multipart_connection.post "/plugin_inspect", payload

      path = /<img src="([^"]*)">/.match(response.body)
      raise ExecutionError, "Failed to capture screen" unless path
      path = path[1]

      unless out[:file]
        out[:file] = /time=([^"]*)">/.match(response.body)
        out_ext = /dev.([^"]*)\?/.match(response.body)
        out[:file] = "dev_#{out[:file][1]}.#{out_ext[1]}" if out[:file]
      end

      response = simple_connection.get path

      File.open(File.join(out[:folder], out[:file]), "wb") do |io|
        io.write(response.body)
      end
      @logger.info "Screen captured to #{File.join(out[:folder], out[:file])}"
    end
  end
  RokuBuilder.register_plugin(Inspector)
end
