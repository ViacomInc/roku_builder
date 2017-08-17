# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Load and validate config files.
  class Config

    attr_reader :parsed

    def initialize(options:)
      @options = options
      @logger = Logger.instance
      @config = nil
      @parsed = nil
    end

    def raw
      @config
    end

    def load
      check_config_file
      load_config
    end

    def parse
      @parsed = ConfigParser.parse(options: @options, config: @config)
    end

    def validate
      validator = ConfigValidator.new(config: @config)
      validator.print_errors
      raise InvalidConfig if validator.is_fatal?
    end

    def edit
      load
      apply_options
      config_string = JSON.pretty_generate(@config)
      file = File.open(@options[:config], "w")
      file.write(config_string)
      file.close
    end

    def configure
      if @options[:configure]
        source_config = File.expand_path(File.join(File.dirname(__FILE__), "..", '..', 'config.json.example'))
        target_config = File.expand_path(@options[:config])
        if File.exist?(target_config)
          unless @options[:edit_params]
            raise InvalidOptions, "Not overwriting config. Add --edit options to do so."
          end
        end
        FileUtils.copy(source_config, target_config)
        edit if @options[:edit_params]
      end
    end

    def root_dir=(root_dir)
      @parsed[:root_dir] = root_dir
    end

    def in=(new_in)
      @parsed[:in] = new_in
    end

    def out=(new_out)
      @parsed[:out] = new_out
    end

    def method_missing(method)
      @parsed[method]
    end

    private

    def check_config_file
      config_file = File.expand_path(@options[:config])
      raise ArgumentError, "Missing Config" unless File.exist?(config_file)
    end


    def load_config
      @config = {parent_config: @options[:config]}
      depth = 1
      while @config[:parent_config]
        parent_config_hash = get_parent_config
        @config[:child_config] = @config[:parent_config]
        @config.delete(:parent_config)
        @config.merge!(parent_config_hash) {|_key, v1, _v2| v1}
        depth += 1
        raise InvalidConfig, "Parent Configs Too Deep." if depth > 10
      end
      fix_config_symbol_values
    end

    def get_parent_config
      begin
        JSON.parse(parent_io.read, {symbolize_names: true})
      rescue JSON::ParserError
        raise InvalidConfig, "Config file is not valid JSON"
      end
    end

    def parent_io
      expand_parent_file_path
      File.open(@config[:parent_config])
    end

    def expand_parent_file_path
      if @config[:child_config]
        @config[:parent_config] = File.expand_path(@config[:parent_config], File.dirname(@config[:child_config]))
      else
        @config[:parent_config] = File.expand_path(@config[:parent_config])
      end
    end

    def fix_config_symbol_values
      if @config[:devices]
        @config[:devices][:default] = @config[:devices][:default].to_sym
      end
      if @config[:projects]
        fix_project_config_symbol_values
        build_inhearited_project_configs
      end
    end

    def fix_project_config_symbol_values
      @config[:projects][:default] = @config[:projects][:default].to_sym
      @config[:projects].each_pair do |key,value|
        next if is_skippable_project_key? key
        if value[:stage_method]
          value[:stage_method] = value[:stage_method].to_sym
        end
      end
    end

    def build_inhearited_project_configs
      @config[:projects].each_pair do |key,value|
        next if is_skippable_project_key? key
        while value[:parent] and @config[:projects][value[:parent].to_sym]
          new_value = @config[:projects][value[:parent].to_sym]
          value.delete(:parent)
          new_value = new_value.deep_merge value
          @config[:projects][key] = new_value
          value = new_value
        end
      end
    end

    def is_skippable_project_key?(key)
      [:project_dir, :default].include?(key)
    end

    def build_edit_state
      {
        project: get_key_for(:project),
        device: get_key_for(:device),
        stage: get_stage_key(project: get_key_for(:project))
      }
    end

    def get_key_for(type)
      project = @options[type].to_sym if @options[type]
      project ||= @config[(type.to_s+"s").to_sym][:default]
      project
    end

    def get_stage_key(project:)
      stage = @options[:stage].to_sym if @options[:stage]
      stage ||= @config[:projects][project][:stages].keys[0].to_sym
      stage
    end

    # Apply the changes in the options string to the config object
    def apply_options
      state = build_edit_state
      changes = RokuBuilder.options_parse(options: @options[:edit_params])
      changes.each {|key,value|
        if [:ip, :user, :password].include?(key)
          @config[:devices][state[:device]][key] = value
        elsif [:directory, :app_name].include?(key) #:folders, :files
          @config[:projects][state[:project]][key] = value
        elsif [:branch].include?(key)
          @config[:projects][state[:project]][:stages][state[:stage]][key] = value
        end
      }
    end
  end
end
