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

    def parse(stage: nil)
      @options[:stage] = stage if stage
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
      @loaded_configs = []
      @config = {parent_config: @options[:config]}
      depth = 1
      while @config[:parent_config]
        @loaded_configs.push(File.expand_path(@config[:parent_config]))
        parent_config_hash = read_config(parent_io)
        @config[:child_config] = @config[:parent_config]
        @config.delete(:parent_config)
        @config.merge!(parent_config_hash) {|_key, v1, _v2| v1}
        depth += 1
        raise InvalidConfig, "Parent Configs Too Deep." if depth > 10
      end
      merge_local_config
      expand_repeatable_stages
      fix_config_symbol_values
      RokuBuilder.process_hook(hook: "post_config_load", params: {config: @config, options: @options})
    end

    def read_config(io)
      begin
        JSON.parse(io.read, {symbolize_names: true})
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

    def merge_local_config
      local_config_path = "./.roku_config.json"
      if File.exist?(local_config_path) and !@loaded_configs.include?(File.expand_path(local_config_path))
        local_config_hash = read_config(File.open(local_config_path))
        add_missing_directories(local_config_hash)
        local_sub_configs = "./.roku_config/*.json"
        @config = @config.deep_merge(local_config_hash)
        Dir.glob("./.roku_config/*.json").each do |sub_config_path|
          sub_config_hash = read_config(File.open(sub_config_path))
          @config = @config.deep_merge(sub_config_hash)
        end
      end
    end

    def add_missing_directories(local_config)
      if local_config[:projects]
        local_config[:projects].each_pair do |key,value|
          unless !value.is_a?(Hash) or value[:directory]
            local_config[:projects][key][:directory] = Pathname.pwd.to_s
          end
        end
      end
    end

    def expand_repeatable_stages
      if @config[:projects]
        @config[:projects].each_pair do |project_key, project|
          unless is_skippable_project_key?(project_key)
            if project[:stages]
              stages_to_add = {}
              project[:stages].each_pair do |repeat, repeat_config|
                if repeat.to_s =~ /!repeat.*/
                  repeat_config[:for].each do |key|
                    repeat_config[:stages].each_pair do |stage_key, stage|
                      stage = deep_copy_replace_key(key, stage)
                      stages_to_add[stage_key.to_s.gsub("{key}", key).to_sym] = stage
                    end
                  end
                  project[:stages].delete(repeat)
                end
              end
              project[:stages].merge!(stages_to_add)
            end
          end
        end
      end
    end

    def deep_copy_replace_key(key, object)
      object = object.dup
      if object.class == Hash
        object.each_pair do |hash_key, hash_value|
          object[hash_key] = deep_copy_replace_key(key, hash_value)
        end
      elsif object.class == Array
        object.each_with_index do |i, value|
          object[i] = deep_copy_replace_key(key, object[i])
        end
      elsif object.class == String
        object.gsub!("{key}", key)
      elsif object.class == Symbol
        object = object.to_s.gsub("{key}", key).to_sym
      end
      object
    end

    def fix_config_symbol_values
      if @config[:devices] and @config[:devices][:default]
        @config[:devices][:default] = @config[:devices][:default].to_sym
      end
      if @config[:projects]
        fix_project_config_symbol_values
        build_inhearited_project_configs
      end
    end

    def fix_project_config_symbol_values
      if @config[:projects][:default]
        @config[:projects][:default] = @config[:projects][:default].to_sym
      end
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
