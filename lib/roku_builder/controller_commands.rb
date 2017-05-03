# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Commands that the controller uses to interface with the rest of the gem.
  class ControllerCommands

    # Provides a hash of all of the options needed to run simple commands via
    # the simple_command method
    # @return [Hash] options to run simple commands
    def self.simple_commands
      {
        delete: { klass: Loader, method: :unload },
        monitor: { klass: Monitor, method: :monitor,
          config_key: :monitor_config },
        navigate: { klass: Navigator, method: :nav, config_key: :navigate_config,
          failure: FAILED_NAVIGATING },
        navigator: { klass: Navigator, method: :interactive },
        screen: { klass: Navigator, method: :screen, config_key: :screen_config,
          failure: FAILED_NAVIGATING },
        key: { klass: Keyer, method: :rekey, config_key: :key },
        genkey: { klass: Keyer, method: :genkey, config_key: :genkey },
        screens: { klass: Navigator, method: :screens },
        text: { klass: Navigator, method: :type, config_key: :text_config },
        screencapture: { klass: Inspector, method: :screencapture, config_key: :screencapture_config,
          failure: FAILED_SCREENCAPTURE },
        applist: {klass: Linker, method: :list},
        profile: {klass: Profiler, method: :run, config_key: :profiler_config}
      }
    end
    # Validate Config
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.validate(logger:)
      logger.info "Config validated"
      SUCCESS
    end
    # Run Sideload
    # @param options [Hash] user options
    # @param config [Config] parsed config
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.sideload(options:, config:, logger:)
      device_config = config.parsed[:device_config].dup
      device_config[:init_params] = config.parsed[:init_params][:loader]
      stager = Stager.new(**config.parsed[:stage_config])
      success = nil
      if stager.stage
        loader = Loader.new(**device_config)
        build_version = ManifestManager.build_version(**config.parsed[:manifest_config])
        options[:build_version] = build_version
        config.update
        success = loader.sideload(**config.parsed[:sideload_config])[0]
      end
      stager.unstage
      if success == SUCCESS
        logger.info "App Sideloaded; staged using #{stager.method}"
      end
      success
    end
    # Run Package
    # @param options [Hash] user options
    # @param config [Conifg] config object
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.package(options:, config:, logger:)
      loader_config = config.parsed[:device_config].dup
      loader_config[:init_params] = config.parsed[:init_params][:loader]
      keyer = Keyer.new(**config.parsed[:device_config])
      stager = Stager.new(**config.parsed[:stage_config])
      loader = Loader.new(**loader_config)
      packager = Packager.new(**config.parsed[:device_config])
      logger.warn "Packaging working directory" if options[:working]
      if stager.stage
        # Sideload #
        code, build_version = loader.sideload(**config.parsed[:sideload_config])
        return code unless code == SUCCESS
        # Key #
        _success = keyer.rekey(**config.parsed[:key])
        # Package #
        options[:build_version] = build_version
        config.update
        success = packager.package(**config.parsed[:package_config])
        logger.info "Signing Successful: #{config.parsed[:package_config][:out_file]}" if success
        return FAILED_SIGNING unless success
        # Inspect #
        if options[:inspect]
          inspect_package(config: config)
        end
      end
      stager.unstage
      logger.info "App Packaged; staged using #{stager.method}"
      SUCCESS
    end
    # Run Sideload
    # @param options [Hash] user options
    # @param config [Config] parsed config
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.test(options:, config:, logger:)
      device_config = config.parsed[:device_config].dup
      device_config[:init_params] = config.parsed[:init_params][:tester]
      stager = Stager.new(**config.parsed[:stage_config])
      if stager.stage
        tester = Tester.new(**device_config)
        tester.run_tests(**config.parsed[:test_config])
      end
      stager.unstage
      SUCCESS
    end

    def self.inspect_package(config:)
      inspector = Inspector.new(**config.parsed[:device_config])
      info = inspector.inspect(config.parsed[:inspect_config])
      inspect_logger = ::Logger.new(STDOUT)
      inspect_logger.formatter = proc {|_severity, _datetime, _progname, msg|
        "%s\n\r" % [msg]
      }
      inspect_logger.unknown "=============================================================="
      inspect_logger.unknown "App Name: #{info[:app_name]}"
      inspect_logger.unknown "Dev ID: #{info[:dev_id]}"
      inspect_logger.unknown "Creation Date: #{info[:creation_date]}"
      inspect_logger.unknown "dev.zip: #{info[:dev_zip]}"
      inspect_logger.unknown "=============================================================="
    end
    private_class_method :inspect_package

    # Run Build
    # @param options [Hash] user options
    # @param config [Config] config object
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.build(options:, config:, logger:)
      ### Build ###
      loader_config = config.parsed[:device_config].dup
      loader_config[:init_params] = config.parsed[:init_params][:loader]
      stager = Stager.new(**config.parsed[:stage_config])
      loader = Loader.new(**loader_config)
      if stager.stage
        build_version = ManifestManager.build_version(**config.parsed[:manifest_config])
        options[:build_version] = build_version
        config.update
        outfile = loader.build(**config.parsed[:build_config])
        logger.info "Build: #{outfile}"
      end
      stager.unstage
      logger.info "App build; staged using #{stager.method}"
      SUCCESS
    end
    # Run update
    # @param config [Config] config object
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.update(config:, logger:)
      ### Update ###
      stager = Stager.new(**config.parsed[:stage_config])
      if stager.stage
        old_version = ManifestManager.build_version(**config.parsed[:manifest_config])
        new_version = ManifestManager.update_build(**config.parsed[:manifest_config])
        logger.info "Update build version from:\n#{old_version}\nto:\n#{new_version}"
      end
      stager.unstage
      SUCCESS
    end

    # Run Deeplink
    # @param options [Hash] user options
    # @param config [Config] config object
    # @param logger [Logger] system logger
    def self.deeplink(options:, config:, logger:)
      if options.has_source?
        sideload(options: options, config: config, logger:logger)
      end

      linker = Linker.new(config.parsed[:device_config])
      if linker.launch(config.parsed[:deeplink_config])
        logger.info "Deeplinked into app"
        return SUCCESS
      else
        return FAILED_DEEPLINKING
      end
    end

    # Run Print
    # @param options [Hash] user options
    # @param config [Config] config object
    def self.print(options:, config:)
      stager = Stager.new(**config.parsed[:stage_config])
      code = nil
      if stager.stage
        code = Scripter.print(attribute: options[:print].to_sym, configs: config.parsed)
      end
      stager.unstage
      code
    end

    def self.dostage(config:)
      stager = Stager.new(**config.parsed[:stage_config])
      stager.stage
    end

    def self.dounstage(config:)
      stager = Stager.new(**config.parsed[:stage_config])
      stager.unstage
    end

    # Run a simple command
    # @param klass [Class] class of object to create
    # @param method [Symbol] methog to run on klass
    # @param config_key [Symbol] config to send from configs if not nil
    # @param config [Configs] config object
    # @param failure [Integer] failure code to return on failure if not nil
    # @param logger [Logger] system logger
    # @return [Integer] Success of failure code
    def self.simple_command(klass:, method:, config_key: nil, config:, failure: nil, logger:)
      klass_config = config.parsed[:device_config].dup
      key = klass.to_s.split("::")[-1].underscore.to_sym
      if config.parsed[:init_params][key]
        klass_config[:init_params] = config.parsed[:init_params][key]
      end
      instance = klass.new(**klass_config)
      if config_key
        success = instance.send(method, config.parsed[config_key])
      else
        success = instance.send(method)
      end
      return failure unless failure.nil? or success
      logger.debug "#{klass} call #{method} successfully"
      SUCCESS
    end
  end
end
