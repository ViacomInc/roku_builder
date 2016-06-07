# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Load/Unload/Build roku applications
  class Loader < Util


    # Set the root directory
    def init(root_dir: nil)
      @root_dir = root_dir
    end

    # Sideload an app onto a roku device
    # @param root_dir [String] Path to the root directory of the roku app
    # @param content [Hash] Hash containing arrays for folder, files, and excludes. Default: nil
    # @return [String] Build version on success, nil otherwise
    def sideload(update_manifest: false, content: nil, infile: nil)
      result = FAILED_SIDELOAD
      outfile = nil
      build_version = nil
      if infile
        build_version = ManifestManager.build_version(root_dir: infile)
        outfile = infile
      else
        # Update manifest
        if update_manifest
          build_version = ManifestManager.update_build(root_dir: @root_dir)
        else
          build_version = ManifestManager.build_version(root_dir: @root_dir)
        end
        outfile = build(build_version: build_version, content: content)
      end
      path = "/plugin_install"
      # Connect to roku and upload file
      conn = multipart_connection
      payload =  {
        mysubmit: "Replace",
        archive: Faraday::UploadIO.new(outfile, 'application/zip')
      }
      response = conn.post path, payload
      # Cleanup
      File.delete(outfile) unless infile
      result = SUCCESS if response.status==200 and response.body=~/Install Success/
      result = IDENTICAL_SIDELOAD if response.status==200 and response.body=~/Identical to previous version/
      [result, build_version]
    end


    # Build an app to sideload later
    # @param root_dir [String] Path to the root directory of the roku app
    # @param build_version [String] Version to assigne to the build. If nil will pull the build version form the manifest. Default: nil
    # @param outfile [String] Path for the output file. If nil will create a file in /tmp. Default: nil
    # @param content [Hash] Hash containing arrays for folder, files, and excludes. Default: nil
    # @return [String] Path of the build
    def build(build_version: nil, outfile: nil, content: nil)
      build_version = ManifestManager.build_version(root_dir: @root_dir) unless build_version
      content ||= {}
      unless content and content[:folders]
        content[:folders] = Dir.entries(@root_dir).select {|entry| File.directory? File.join(@root_dir, entry) and !(entry =='.' || entry == '..') }
      end
      unless content and content[:files]
        content[:files] = Dir.entries(@root_dir).select {|entry| File.file? File.join(@root_dir, entry)}
      end
      content[:excludes] = [] unless content and content[:excludes]
      outfile = "/tmp/build_#{build_version}.zip" unless outfile
      File.delete(outfile) if File.exist?(outfile)
      io = Zip::File.open(outfile, Zip::File::CREATE)
      # Add folders to zip
      content[:folders].each do |folder|
        base_folder = File.join(@root_dir, folder)
        entries = Dir.entries(base_folder)
        entries.delete(".")
        entries.delete("..")
        writeEntries(@root_dir, entries, folder, content[:excludes], io)
      end
      # Add file to zip
      writeEntries(@root_dir, content[:files], "", content[:excludes], io)
      io.close()
      outfile
    end

    # Remove the currently sideloaded app
    def unload()
      path = "/plugin_install"

      # Connect to roku and upload file
      conn = multipart_connection
      payload =  {
        mysubmit: "Delete",
        archive: ""
      }
      response = conn.post path, payload
      if response.status == 200 and response.body =~ /Install Success/
        return true
      end
      return false
    end

    private

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
            io.get_output_stream(zipFilePath) { |f| f.puts(File.open(diskFilePath, "rb").read()) }
          end
        end
      }
    end
  end
end
