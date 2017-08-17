# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder
  class Manifest

    def self.generate(config:, attributes:)
      FileUtils.touch(File.join(config.parsed[:root_dir], "manifest"))
      manifest = new(config: config)
      manifest.update(attributes: default_params.merge(attributes))
      manifest
    end

    def initialize(config:)
      @config = config
      @attributes = {}
      check_for_manifest
      read
    end

    def update(attributes:)
      update_attributes(attributes)
      write_file
    end

    def increment_build_version
      build_version_parts = @attributes[:build_version].split(".")
      if build_version_parts.length == 2
        build_version_parts[0] = Time.now.strftime("%m%d%y")
        build_version_parts[1] = build_version_parts[1].to_i + 1
        @attributes[:build_version] = build_version_parts.join(".")
      else
        @attributes[:build_version] = build_version_parts[0].to_i + 1
      end
      write_file
    end

    def method_missing(method)
      @attributes[method]
    end

    private

    def read
      process_folder = -> (path){
        File.open(path, 'r') do |file|
          read_attributes(file)
        end
      }
      process_zip = -> (entry){
        entry.get_input_stream do |file|
          read_attributes(file)
        end
      }
      process_manifest(process_folder, process_zip)
    end

    def read_attributes(file)
      file.each_line do |line|
        key, value = line.split("=")
        key = key.chomp.to_sym
        value.chomp! if value
        @attributes[key] = value
      end
    end

    def check_for_manifest
      process_folder = -> (path) {
        raise ManifestError, "Missing Manifest: #{path}" unless File.exist?(path)
      }
      process_zip = -> (entry) {
          raise ManifestError, "Missing Manifest in #{root_dir}" unless entry
      }
      process_manifest(process_folder, process_zip)
    end

    def process_manifest(process_folder, process_zip)
      root_dir = @config.root_dir
      if File.directory?(root_dir)
        path = File.join(root_dir, "manifest")
        process_folder.call(path)
      elsif File.extname(root_dir) == ".zip"
        Zip::File.open(root_dir) do |zip_file|
          entry = zip_file.glob("manifest").first
          process_zip.call(entry)
        end
      end
    end

    def update_attributes(attributes)
      @attributes.merge!(attributes)
    end

    def write_file
      root_dir = @config.parsed[:root_dir]
      raise ManifestError, "Cannot Update zipped manifest" if File.extname(root_dir) == ".zip"
      path = File.join(root_dir, "manifest")
      File.open(path, "w") do |file|
        @attributes.each_pair do |key,value|
          if value
            file.puts "#{key}=#{value}"
          else
            file.puts key
          end
        end
      end
    end

    def self.default_params
      {
        title: "Default Title",
        major_version: 1,
        minor_version: 0,
        build_version: "010101.0001",
        mm_icon_focus_hd: "<insert hd focus icon url>",
        splash_screen_fhd: "<insert fhd splash screen url>"
      }
    end
  end
end

