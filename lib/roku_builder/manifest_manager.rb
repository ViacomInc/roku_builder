# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Updates or retrives build version
  class ManifestManager

    # Updates the build version in the manifest file
    # @param root_dir [String] Path to the root directory for the app
    # @return [String] Build version on success, empty string otherwise
    def self.update_build(root_dir:)
      return MISSING_MANIFEST unless self.check_manifest(root_dir: root_dir)
      build_version = self.build_version(root_dir: root_dir).split(".")
      if 2 == build_version.length
        iteration = build_version[1].to_i + 1
        build_version[0] = Time.now.strftime("%m%d%y")
        build_version[1] = iteration
        build_version = build_version.join(".")
      else
        iteration = build_version[0].to_i + 1
        build_version = iteration.to_s
      end
      self.update_manifest(root_dir: root_dir, attributes: {build_version: build_version})
      self.build_version(root_dir: root_dir)
    end


    # Retrive the build version from the manifest file
    # @param root_dir [String] Path to the root directory for the app
    # @return [String] Build version on success, empty string otherwise
    def self.build_version(root_dir:)
      return MISSING_MANIFEST unless self.check_manifest(root_dir: root_dir)
      read_manifest(root_dir: root_dir)[:build_version]
    end

    def self.read_manifest(root_dir:)
      return MISSING_MANIFEST unless self.check_manifest(root_dir: root_dir)
      attrs = {}
      get_attrs = lambda  { |file|
        file.each_line do |line|
          key, value = line.split("=")
          if value
            attrs[key.chomp.to_sym]= value.chomp
          elsif key and !key.chomp.empty?
            attrs[key.chomp.to_sym]= nil
          end
        end
      }
      if File.directory?(root_dir)
        path = File.join(root_dir, 'manifest')
        File.open(path, 'r', &get_attrs)
      elsif File.extname(root_dir) == ".zip"
        Zip::File.open(root_dir) do |zip_file|
          entry = zip_file.glob("manifest").first
          entry.get_input_stream(&get_attrs)
        end
      end
      attrs
    end

    # Update attributes in the app manifest
    # It will add missing attributes but not remove them
    # @param root_dir [String] The app root directory
    # @param attributes [Hash] The new attributes for the app manifest
    def self.update_manifest(root_dir:, attributes:, set_default: true)
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
        elsif set_default
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

    # Check to make sure that the manifest file exists
    # @param root_dir [String] Path to the root directory for the app
    # @return [Boolean] True if manifest exists, false otherwise
    def self.check_manifest(root_dir:)
      return false unless File.exist?(root_dir)
      if File.directory?(root_dir)
        path = File.join(root_dir, 'manifest')
        return false unless File.exist?(path)
      elsif File.extname(root_dir) == ".zip"
        Zip::File.open(root_dir) do |zip_file|
          entry = zip_file.glob("manifest").first
          return false unless entry
        end
      end
      true
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
