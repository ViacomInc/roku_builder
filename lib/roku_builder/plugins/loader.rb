# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Load/Unload/Build roku applications
  class Loader < Util
    extend Plugin

    def self.commands
      {
        sideload: {source: true, device: true, stage: true},
        build: {source: true, stage: true, exclude: true},
        delete: {device: true}
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("-l", "--sideload", "Sideload an app") do
        options[:sideload] = true
      end
      parser.on("-d", "--delete", "Delete the currently sideloaded app") do
        options[:delete] = true
      end
      parser.on("-b", "--build", "Build a zip to be sideloaded") do
        options[:build] = true
      end
      parser.separator "Options:"
      parser.on("-x", "--exclude", "Apply exclude config to sideload") do
        options[:exclude] = true
      end
    end

    def self.dependencies
      [Navigator]
    end

    # Sideload an app onto a roku device
    def sideload(options:)
      delete(options: options, ignoreFailure: true)
      did_build = false
      unless options[:in]
        did_build = true
        build(options: options)
      end
      keep_build_file = is_build_command(options) and options[:out]
      upload
      # Cleanup
      File.delete(file_path(:in)) if did_build and not keep_build_file
    end


    # Build an app to sideload later
    def build(options:)
      @options = options
      build_zip(setup_build_content)
      if options.command == :build or (options.command == :sideload and options[:out])
        @logger.info "File Path: "+file_path(:out)
      end
      @config.in = @config.out #setting in path for possible sideload
      file_path(:out)
    end

    # Remove the currently sideloaded app
    def delete(options:, ignoreFailure: false)
      payload =  {mysubmit: "Delete", archive: ""}
      response  = multipart_connection.post "/plugin_install", payload
      unless response.status == 200 and response.body =~ /Delete Succeeded/ or ignoreFailure
        raise ExecutionError, "Failed Unloading"
      end
    end

    def copy(options:, path:)
      @options = options
      @target = path
      copy_channel_files(setup_build_content)
    end

    private

    def is_build_command(options)
      [:sideload, :build].include? options.command
    end

    def upload
      payload =  {
        mysubmit: "Replace",
        archive: Faraday::UploadIO.new(file_path(:in), 'application/zip')
      }
      response = multipart_connection.post "/plugin_install", payload
      @logger.debug("Status: #{response.status}, Body: #{response.body}")
      if response.status==200 and response.body=~/Identical to previous version/
        @logger.warn("Sideload identival to previous version")
      elsif not (response.status==200 and response.body=~/Install Success/)
        raise ExecutionError, "Failed Sideloading"
      end
    end

    def file_path(type)
      file = @config.send(type)[:file]
      file ||= Manifest.new(config: @config).build_version
      file = file+".zip" unless file.end_with?(".zip")
      File.join(@config.send(type)[:folder], file)
    end

    def setup_build_content()
      content = {}
      content[:excludes] = []
      if @options[:current]
        content[:folders] = Dir.entries(@config.root_dir).select {|entry| File.directory? File.join(@config.root_dir, entry) and !(entry =='.' || entry == '..') }
        content[:files] = Dir.entries(@config.root_dir).select {|entry| File.file? File.join(@config.root_dir, entry)}
      else
        content[:folders] = @config.project[:folders]
        content[:files] = @config.project[:files]
        content[:excludes] = @config.project[:excludes] if @config.project[:excludes] and (@options[:exclude] or @options.exclude_command?)
      end
      content
    end

    def build_zip(content)
      path = file_path(:out)
      File.delete(path) if File.exist?(path)
      io = Zip::File.open(path, Zip::File::CREATE)
      # Add folders to zip
      content[:folders].each do |folder|
        base_folder = File.join(@config.root_dir, folder)
        if File.exist?(base_folder)
          entries = Dir.entries(base_folder)
          entries.delete(".")
          entries.delete("..")
          writeEntries(@config.root_dir, entries, folder, content[:excludes], io)
        else
          @logger.warn "Missing Folder: #{base_folder}"
        end
      end
      # Add file to zip
      writeEntries(@config.parsed[:root_dir], content[:files], "", content[:excludes], io)
      io.close()
    end

    # Recursively write directory contents to a zip archive
    # @param root_dir [String] Path of the root directory
    # @param entries [Array<String>] Array of file paths of files/directories to store in the zip archive
    # @param path [String] The path of the current directory starting at the root directory
    # @param io [IO] zip IO object
    def writeEntries(root_dir, entries, path, excludes, io)
      entries.each { |e|
        zipFilePath = path == "" ? e : File.join(path, e)
        diskFilePath = File.join(root_dir, zipFilePath)
        if File.directory?(diskFilePath)
          io.mkdir(zipFilePath)
          subdir =Dir.entries(diskFilePath); subdir.delete("."); subdir.delete("..")
          writeEntries(root_dir, subdir, zipFilePath, excludes, io)
        else
          unless excludes.include?(zipFilePath)
            if File.exist?(diskFilePath)
              file = diskFilePath.rindex(/\//)

              if zipFilePath.end_with?("manifest", ".gif", ".png", ".brs", ".xml", ".jpg", ".json", ".mov", ".ttf", ".otf", ".p12", ".cer")
                io.get_output_stream(zipFilePath) { |f| f.puts(File.open(diskFilePath, "rb").read()) }
              else
                @logger.warn "Ignored file with invalid Roku filetype " + diskFilePath[file, diskFilePath.length - file]
              end
            else
              @logger.warn "Missing File: #{diskFilePath}"
            end
          end
        end
      }
    end
    def copy_channel_files(content)
      [:files, :folders].each do |type|
        content[type].each do |entity|
          begin
            FileUtils.copy_entry(File.join(@config.parsed[:root_dir], entity), File.join(@target, entity))
          rescue Errno::ENOENT
            @logger.warn "Missing Entry: #{entity}"
          end
        end
      end
    end
  end
  RokuBuilder.register_plugin(Loader)
end
