# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Updates or retrives build version
  class ManifestManager

    # Updates the build version in the manifest file
    # @param root_dir [String] Path to the root directory for the app
    # @return [String] Build version on success, empty string otherwise
    def self.update_build(root_dir:)

      build_version = ""

      temp_file = Tempfile.new('manifest')
      path = File.join(root_dir, 'manifest')
      begin
        File.open(path, 'r') do |file|
          file.each_line do |line|
            if line.include?("build_version")

              #Update build version.
              build_version = line.split(".")
              if 2 == build_version.length
                iteration = build_version[1].to_i + 1
                build_version[0] = Time.now.strftime("%m%d%y")
                build_version[1] = iteration
                build_version = build_version.join(".")
              else
                #Use current date.
                build_version = Time.now.strftime("%m%d%y")+".1"
              end
              temp_file.puts "build_version=#{build_version}"
            else
              temp_file.puts line
            end
          end
        end
        temp_file.rewind
        FileUtils.cp(temp_file.path, path)
      ensure
        temp_file.close
        temp_file.unlink
      end
      build_version
    end

    # Retrive the build version from the manifest file
    # @param root_dir [String] Path to the root directory for the app
    # @return [String] Build version on success, empty string otherwise
    def self.build_version(root_dir:)
      build_version = ""
      get_version = lambda  { |file|
        file.each_line do |line|
          if line.include?("build_version")
            build_version = line.split("=")[1].chomp
          end
        end
      }
      if File.directory?(root_dir)
        path = File.join(root_dir, 'manifest')
        build_version = ""
        File.open(path, 'r', &get_version)
      elsif File.extname(root_dir) == ".zip"
        Zip::File.open(root_dir) do |zip_file|
          entry = zip_file.glob("manifest").first
          entry.get_input_stream(&get_version)
        end
      end
      build_version
    end

    # Update attributes in the app manifest
    # It will add missing attributes but not remove them
    # @param root_dir [String] The app root directory
    # @param attributes [Hash] The new attributes for the app manifest
    def self.update_manifest(root_dir:, attributes:)
      temp_file = Tempfile.new('manifest')
      path = File.join(root_dir, 'manifest')
      new_params = attributes.dup
      begin
        if File.exist?(path)
          File.open(path, 'r') do |file|
            file.each_line do |line|
              key = line.split("=")[0]
              if new_params.include?(key.to_sym)
                temp_file.puts("#{key}=#{new_params[key.to_sym]}")
                new_params.delete(key.to_sym)
              else
                temp_file.puts(line)
              end
            end
          end
        else
          new_params = self.default_params().merge(new_params)
        end
        new_params.each_pair do |key, value|
          temp_file.puts("#{key}=#{value}")
        end
        temp_file.rewind
        FileUtils.cp(temp_file.path, path)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    # Returns the default manafest values
    # @return [Hash] default manifest values
    def self.default_params
      {
        title: "Default Title",
        major_version: 1,
        minor_version: 0,
        build_version: "010101.0001",
        mm_icon_focus_hd: "<insert hd focus icon url>",
        mm_icon_focus_sd: "<insert sd focus icon url>"
      }
    end
  end
end
