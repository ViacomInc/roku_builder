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
      setup_outfile
      setup_project_config
      setup_stage_config
      setup_sideload_config
      setup_package_config
      setup_monitor_configs
      setup_navigate_configs
      setup_manifest_config
      setup_deeplink_configs
      setup_text_configs
      setup_test_configs
      setup_screencapture_configs
      setup_screen_config
      setup_profiler_configs
      setup_genkey_configs
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
        else
          @options[:project] = @config[:projects][:default]
        end
      end
    end

    def project_required
      non_project_source = ([:current, :in] & @options.keys).count > 0
      @options.source_command? and not non_project_source
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
      if @config[:projects][:project_dir]
        repo_path = Pathname.new(File.join(@config[:projects][:project_dir], project_config[:directory])).realdirpath
      else
        repo_path = Pathname.new(project_config[:directory]).realdirpath
      end
    end

    def setup_outfile
      @parsed[:out] = {file: nil, folder: nil}
      if @options[:out]
        if out_file_defined?
          setup_outfile_and_folder
        else
          @parsed[:out][:folder] = @options[:out]
        end
      end
      set_default_outfile
    end

    def out_file_defined?
      @options[:out].end_with?(".zip") or @options[:out].end_with?(".pkg") or @options[:out].end_with?(".jpg")
    end

    def setup_outfile_and_folder
      @parsed[:out][:folder], @parsed[:out][:file] = Pathname.new(@options[:out]).split.map{|p| p.to_s}
      if @parsed[:out][:folder] == "." and not @options[:out].start_with?(".")
        @parsed[:out][:folder] = nil
      else
        @parsed[:out][:folder] = File.expand_path(@parsed[:out][:folder])
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
        @parsed[:project_config] = @config[:projects][@options[:project].to_sym]
        raise ParseError, "Unknown Project: #{@options[:project]}" unless @parsed[:project_config]
        set_project_directory
        check_for_working
      end
    end

    def stub_project_config_for_current
      pwd =  Pathname.pwd.to_s
      raise ParseError, "Missing Manifest" unless File.exist?(File.join(pwd, "manifest"))
      @parsed[:project_config] = {
        directory: pwd,
        folders: nil,
        files: nil,
        stage_method: :current
      }
    end

    def set_project_directory
      if @config[:projects][:project_dir]
        @parsed[:project_config][:directory] = File.join(@config[:projects][:project_dir], @parsed[:project_config][:directory])
      end
      unless Dir.exist?(@parsed[:project_config][:directory])
        raise ParseError, "Missing project dirtectory: #{@parsed[:project_config][:dirtectory]}"
      end
    end

    def check_for_working
      @parsed[:project_config][:stage_method] = :working if @options[:working]
    end


    def setup_stage_config
      setup_mininal_stage_configs
      setup_project_stage_config if project_required
    end

    def setup_mininal_stage_configs
      @parsed[:stage_config] = {}
      @parsed[:stage_config][:method] = ([:in, :current] & @options.keys).first
      @parsed[:stage] = @options[:stage].to_sym if @options[:stage]
    end

    def setup_project_stage_config
      @parsed[:stage] ||= @parsed[:project_config][:stages].keys[0].to_sym
      @parsed[:stage_config][:root_dir] = @parsed[:project_config][:directory]
      raise ParseError, "Unknown Stage: #{@parsed[:stage]}" unless @parsed[:project_config][:stages][@parsed[:stage]]
      setup_staging_method
      setup_staging_key
    end

    def setup_staging_method
      @parsed[:stage_config][:method] = @parsed[:project_config][:stage_method]
      unless [:git, :script, :current, :working].include? @parsed[:stage_config][:method]
        raise ParseError, "Unknown Stage Method: #{@parsed[:stage_config][:method]}"
      end
    end

    def setup_staging_key
      case @parsed[:stage_config][:method]
      when :git
        if @options[:ref]
          @parsed[:stage_config][:key] = @options[:ref]
        else
          @parsed[:stage_config][:key] = @parsed[:project_config][:stages][@parsed[:stage]][:branch]
        end
      when :script
        @parsed[:stage_config][:key] = @parsed[:project_config][:stages][@parsed[:stage]][:script]
      end
    end

    def setup_sideload_config
      root_dir, content = setup_project_values
      # Create Sideload Config
      @parsed[:sideload_config] = {
        update_manifest: @options[:update_manifest],
        infile: @options[:in],
        content: content
      }
      # Create Build Config
      @parsed[:build_config] = { content: content }
      @parsed[:init_params][:loader] = { root_dir: root_dir }
    end

    def setup_project_values
      if @parsed[:project_config]
        root_dir = @parsed[:project_config][:directory]
        content = {
          folders: @parsed[:project_config][:folders],
          files: @parsed[:project_config][:files],
        }
        content[:excludes] = @parsed[:project_config][:excludes] if add_excludes?
        [root_dir, content]
      else
        [nil, nil]
      end
    end

    def add_excludes?
      @options[:exclude] or @options.exclude_command?
    end

    def setup_package_config
      setup_key_config if @options[:package] or @options[:key]
      if @options[:package]
        setup_package_config_hashes
        setup_package_config_out_files
      end
    end

    def setup_key_config
      @parsed[:key] = @parsed[:project_config][:stages][@parsed[:stage]][:key]
      get_global_key_config if @parsed[:key].class == String
    end

    def get_global_key_config
      raise ParseError, "Unknown Key: #{@parsed[:key]}" unless @config[:keys][@parsed[:key].to_sym]
      @parsed[:key] = @config[:keys][@parsed[:key].to_sym]
      if @config[:keys][:key_dir]
        @parsed[:key][:keyed_pkg] = File.join(@config[:keys][:key_dir], @parsed[:key][:keyed_pkg])
      end
      unless File.exist?(@parsed[:key][:keyed_pkg])
        raise ParseError, "Bad key file: #{@parsed[:key][:keyed_pkg]}"
      end
    end

    def setup_package_config_hashes
      @parsed[:package_config] = {
        password: @parsed[:key][:password],
        app_name_version: "#{@parsed[:project_config][:app_name]} - #{@parsed[:stage]}"
      }
      @parsed[:inspect_config] = {
        password: @parsed[:key][:password]
      }
    end

    def setup_package_config_out_files
      if @parsed[:out][:file]
        @parsed[:package_config][:out_file] = File.join(@parsed[:out][:folder], @parsed[:out][:file])
        @parsed[:inspect_config][:pkg] = File.join(@parsed[:out][:folder], @parsed[:out][:file])
      end
    end

    def setup_monitor_configs
      if @options[:monitor]
        @parsed[:monitor_config] = {type: @options[:monitor].to_sym}
        if @options[:regexp]
          @parsed[:monitor_config][:regexp] = /#{@options[:regexp]}/
        end
      end
    end

    def setup_navigate_configs
      @parsed[:init_params][:navigator] = {mappings: generate_maggings}
      if @options[:navigate]
        @parsed[:navigate_config] = {
          commands: @options[:navigate].split(/, */).map{|c| c.to_sym}
        }
      end
    end

    def generate_maggings
      mappings = {}
      if @config[:input_mapping]
        @config[:input_mapping].each_pair {|key, value|
          unless "".to_sym == key
            key = key.to_s.sub(/\\e/, "\e").to_sym
            mappings[key] = value
          end
        }
      end
      mappings
    end

    def setup_manifest_config
      @parsed[:manifest_config] = {
        root_dir: get_root_dir
      }
    end

    def get_root_dir
      root_dir = @parsed[:project_config][:directory] if @parsed[:project_config]
      root_dir = @options[:in] if @options[:in]
      root_dir = Pathname.pwd.to_s if @options[:current]
      root_dir
    end if

    def setup_deeplink_configs
      @parsed[:deeplink_config] = {options: @options[:deeplink]}
      if @options[:app_id]
        @parsed[:deeplink_config][:app_id] = @options[:app_id]
      end
    end
    def setup_text_configs
      @parsed[:text_config] = {text: @options[:text]}
    end
    def setup_test_configs
      @parsed[:test_config] = {sideload_config: @parsed[:sideload_config]}
      @parsed[:init_params][:tester] = { root_dir: get_root_dir }
    end
    def setup_screencapture_configs
      @parsed[:screencapture_config] = {
        out_folder: @parsed[:out][:folder],
        out_file: @parsed[:out][:file]
      }
    end
    def setup_screen_config
      if @options[:screen]
        @parsed[:screen_config] = {type: @options[:screen].to_sym}
      end
    end
    def setup_profiler_configs
      if @options[:profile]
        @parsed[:profiler_config] = {command: @options[:profile].to_sym}
      end
    end
    def setup_genkey_configs
      @parsed[:genkey] = {}
      if @options[:out_file]
        @parsed[:genkey][:out_file] = File.join(@options[:out_folder], @options[:out_file])
      end
    end
  end
end
