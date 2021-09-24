# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class ConfigParser

    attr_reader :parsed

    def self.parse(options:, config:)
      parser = new(options: options, config: config)
      parser.parsed
    end

    def initialize(options:, config:)
      @logger = Logger.instance
      @options = options
      @config = config
      @parsed = {init_params: {}}
      parse_config
    end

    def parse_config
      process_in_argument
      setup_device
      setup_project
      setup_in_out_file
      setup_project_config
      setup_stage_config
      setup_key_config
      setup_root_dir
      setup_input_mappings
    end

    def process_in_argument
      @options[:in] = File.expand_path(@options[:in]) if @options[:in]
    end

    def setup_device
      @options[:device] = @config[:devices][:default] unless @options[:device]
      @parsed[:device_config] = @config[:devices][@options[:device].to_sym]
      raise ArgumentError, "Unknown device: #{@options[:device]}" unless @parsed[:device_config]
    end

    def setup_project
      if project_required and not @options[:project]
        project = current_project
        if project
          @options[:project] = project
        elsif @config[:projects][:default]
          @options[:project] = @config[:projects][:default]
        end
        raise ArgumentError, "A project is required for that command" unless @options[:project]
      end
    end

    def project_required
      non_project_source = ([:current, :in] & @options.keys).count > 0
      @options.has_source? and not non_project_source
    end

    def current_project
      @config[:projects].each_pair do |key,value|
        return key if is_current_project?(project_config: value)
      end
      nil
    end

    def is_current_project?(project_config:)
      return false unless project_config.is_a?(Hash)
      repo_path = get_repo_path(project_config: project_config)
      Pathname.pwd.descend do |path_parent|
        return true if path_parent == repo_path
      end
    end

    def get_repo_path(project_config:)
      if @config[:projects][:project_dir] and !Pathname.new(project_config[:directory]).absolute?
        Pathname.new(File.join(@config[:projects][:project_dir], project_config[:directory])).realdirpath
      else
        Pathname.new(project_config[:directory]).realdirpath
      end
    end

    def setup_in_out_file
      [:in, :out].each do |type|
        @parsed[type] = {file: nil, folder: nil}
        if @options[type]
          if file_defined?(type)
            setup_file_and_folder(type)
          elsif @options[type]
            @parsed[type][:folder] = File.expand_path(@options[type])
          end
        end
      end
      set_default_outfile
    end

    def file_defined?(type)
      @options[type].end_with?(".zip") or @options[type].end_with?(".pkg") or @options[type].end_with?(".jpg")
    end

    def setup_file_and_folder(type)
      @parsed[type][:folder], @parsed[type][:file] = Pathname.new(@options[type]).split.map{|p| p.to_s}
      if @parsed[type][:folder] == "." and not @options[type].start_with?(".")
        @parsed[type][:folder] = nil
      else
        @parsed[type][:folder] = File.expand_path(@parsed[type][:folder])
      end
    end

    def set_default_outfile
      unless @parsed[:out][:folder]
        @parsed[:out][:folder] = Dir.tmpdir
      end
    end

    def setup_project_config
      if @options[:current]
        stub_project_config_for_current
      elsif  project_required
        @parsed[:project] = @config[:projects][@options[:project].to_sym].dup
        raise ParseError, "Unknown Project: #{@options[:project]}" unless @parsed[:project]
        set_project_directory
        convert_to_source_files
        check_for_working
      end
    end

    def stub_project_config_for_current
      pwd =  Pathname.pwd.to_s
      manifest = File.join(pwd, "manifest")
      raise ParseError, "Missing Manifest: #{manifest}" unless File.exist?(manifest)
      @parsed[:project] = {
        directory: pwd,
        source_files: nil,
        stage_method: :current
      }
    end

    def set_project_directory
      if @config[:projects][:project_dir]  and !Pathname.new(@parsed[:project][:directory]).absolute?
        @parsed[:project][:directory] = File.join(@config[:projects][:project_dir], @parsed[:project][:directory])
      end
      unless Dir.exist?(@parsed[:project][:directory])
        raise ParseError, "Missing project directory: #{@parsed[:project][:directory]}"
      end
    end

    def convert_to_source_files
      unless @parsed[:project][:source_files]
        @parsed[:project][:source_files] = @parsed[:project][:files] + @parsed[:project][:folders]
        @parsed[:project].delete(:files)
        @parsed[:project].delete(:folders)
      end
    end

    def check_for_working
      @parsed[:project][:stage_method] = :working if @options[:working]
    end


    def setup_stage_config
      if project_required
        stage = @options[:stage].to_sym if @options[:stage]
        stage ||= @parsed[:project][:stages].keys[0].to_sym
        raise ParseError, "Unknown Stage: #{stage}" unless @parsed[:project][:stages][stage]
        @parsed[:stage] = @parsed[:project][:stages][stage]
      end
    end

    def setup_key_config
      if @options.keyed_command?
        if @parsed[:stage]
          @parsed[:key] = @parsed[:stage][:key]
          get_global_key_config if @parsed[:key].class == String
          test_key_file
        end
      end
    end

    def get_global_key_config
      raise ParseError, "Unknown Key: #{@parsed[:key]}" unless @config[:keys][@parsed[:key].to_sym]
      @parsed[:key] = @config[:keys][@parsed[:key].to_sym].dup
      if @config[:keys][:key_dir]  and !@parsed[:key][:keyed_pkg].start_with?("./")
        @parsed[:key][:keyed_pkg] = File.join(@config[:keys][:key_dir], @parsed[:key][:keyed_pkg])
      end
    end

    def test_key_file
      if @parsed[:key] and not File.exist?(@parsed[:key][:keyed_pkg])
        raise ParseError, "Bad key file: #{@parsed[:key][:keyed_pkg]}"
      end
    end

    def setup_root_dir
      @parsed[:root_dir] = get_root_dir
    end

    def get_root_dir
      root_dir = @parsed[:project][:directory] if @parsed[:project]
      root_dir = @options[:in] if @options[:in]
      root_dir = Pathname.pwd.to_s if @options[:current]
      root_dir
    end

    def setup_input_mappings
      @parsed[:input_mappings] = @config[:input_mappings]
    end
  end
end
