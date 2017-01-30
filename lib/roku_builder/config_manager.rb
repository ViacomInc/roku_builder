# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Load and validate config files.
  class ConfigManager

    # Load config file and generate intermeidate configs
    # @param options [Hash] The options hash
    # @param logger [Logger] system logger
    # @return [Integer] Return code
    # @return [Hash] Loaded config
    # @return [Hash] Intermeidate configs
    def self.load_config(options:, logger:)
      config_file = File.expand_path(options[:config])
      return MISSING_CONFIG unless File.exist?(config_file)
      code = SUCCESS
      config = ConfigManager.get_config(config: config_file, logger: logger)
      return INVALID_CONFIG unless config
      codes = ConfigValidator.validate_config(config: config)
      fatal = false
      warning = false
      codes.each {|a_code|
        if a_code > 0
          logger.fatal "Invalid Config: "+ ConfigValidator.error_codes()[a_code]
          fatal = true
        elsif a_code < 0
          logger.warn "Depricated Config: "+ ConfigValidator.error_codes()[a_code]
          warning = true
        elsif a_code == 0 and options[:validate]
          logger.info "Config Valid"
        end
      }
      return [INVALID_CONFIG, nil, nil] if fatal
      code = DEPRICATED_CONFIG if warning

      parse_code, configs = ConfigParser.parse_config(options: options, config: config, logger: logger)
      unless parse_code == SUCCESS
        return [parse_code, nil, nil]
      end
      [code, config, configs]
    end

    # Loads the roku config from file
    # @param config [String] path for the roku config
    # @return [Hash] roku config object
    def self.get_config(config:, logger:)
      begin
        config = {parent_config: config}
        depth = 1
        while config[:parent_config]
          config_parent = JSON.parse(File.open(config[:parent_config]).read, {symbolize_names: true})
          config.delete(:parent_config)
          config.merge!(config_parent) {|key, v1, v2| v1}
          depth += 1
          if depth > 10
            logger.fatal "Parent configs too deep."
            return nil
          end
        end
        config[:devices][:default] = config[:devices][:default].to_sym
        config[:projects][:default] = config[:projects][:default].to_sym
        config[:projects].each_pair do |key,value|
          next if key == :default
          if value[:stage_method]
            value[:stage_method] = value[:stage_method].to_sym
          end
        end
        config[:projects].each_pair do |key, value|
          unless key == :default
            if value[:parent] and config[:projects][value[:parent].to_sym]
              new_value = config[:projects][value[:parent].to_sym]
              new_value = new_value.deep_merge value
              config[:projects][key] = new_value
            end
          end
        end
        config
      rescue JSON::ParserError
        logger.fatal "Config file is not valid JSON"
        nil
      end
    end


    # Edit the roku config
    # @param config [String] path for the roku config
    # @param options [String] options to set in the config
    # @param stage[String] which stage to use
    # @return [Boolean] success
    def self.edit_config(config:, options:, logger:)
      config_object = get_config(config: config, logger: logger)
      return false unless config_object
      project = options[:project].to_sym if options[:project]
      project = config_object[:projects][:default] unless options[:project]
      device = options[:device].to_sym if options[:device]
      device = config_object[:devices][:default] unless options[:device]
      stage = options[:stage].to_sym if options[:stage]
      stage ||= config_object[:projects][project][:stages].keys[0].to_sym
      state = {
        project: project,
        device: device,
        stage: stage
      }
      apply_options(config_object: config_object, options: options[:edit_params], state: state)
      config_string = JSON.pretty_generate(config_object)
      file = File.open(config, "w")
      file.write(config_string)
      file.close
      return true
    end

    # Apply the changes in the options string to the config object
    # @param config_object [Hash] The config loaded from file
    # @param options [String] The string of options passed in by the user
    # @param state [Hash] The state of the config the user is editing
    def self.apply_options(config_object:, options:, state:)
      changes = Util.options_parse(options: options)
      changes.each {|key,value|
        if [:ip, :user, :password].include?(key)
          config_object[:devices][state[:device]][key] = value
        elsif [:directory, :app_name].include?(key) #:folders, :files
          config_object[:projects][state[:project]][key] = value
        elsif [:branch].include?(key)
          config_object[:projects][state[:project]][:stages][state[:stage]][key] = value
        end
      }
    end
    private_class_method :apply_options

    # Update the intermeidate configs
    # @param configs [Hash] Intermeidate configs hash
    # @param options [Hash] Options hash
    # @return [Hash] New intermeidate configs hash
    def self.update_configs(configs:, options:)
      if options[:build_version]
        configs[:package_config][:app_name_version] = "#{configs[:project_config][:app_name]} - #{configs[:stage]} - #{options[:build_version]}" if configs[:package_config]
        unless configs[:out][:file]
          configs[:out][:file] = "#{configs[:project_config][:app_name]}_#{configs[:stage]}_#{options[:build_version]}"
        end
        pathname = File.join(configs[:out][:folder], configs[:out][:file])
        configs[:package_config][:out_file] = pathname if configs[:package_config]
        configs[:build_config][:out_file]   = pathname if configs[:build_config]
        if configs[:sideload_config] and options[:out]
          configs[:sideload_config][:out_file]   = pathname
        end
        configs[:inspect_config][:pkg] = configs[:package_config][:out_file] if configs[:inspect_config] and configs[:package_config]
      end
      return configs
    end
  end
end
