# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Controls all interaction with other classes
  class Controller

    # Run the builder
    # @param options [Hash] The options hash
    def self.run(options:)
      options = Options.new(options: options)

      initialize_logger(options: options)

      # Configure Gem
      configure_code = configure(options: options, logger: Logger.instance)
      ErrorHandler.handle_configure_codes(configure_code: configure_code, logger: Logger.instance)

      # Load Config
      config = Config.new(options: options)
      config.load
      config.validate
      config.parse

      # Check devices
      device_code = check_devices(options: options, config: config, logger: Logger.instance)
      ErrorHandler.handle_device_codes(device_code: device_code, logger: Logger.instance)

      # Run Commands
      command_code = execute_commands(options: options, config: config, logger: Logger.instance)
      ErrorHandler.handle_command_codes(command_code: command_code, logger: Logger.instance)
    end

    def self.initialize_logger(options:)
      if options[:debug]
        Logger.set_debug
      elsif options[:verbose]
        Logger.set_info
      else
        Logger.set_warn
      end
    end

    # Run commands
    # @param options [Hash] The options hash
    # @return [Integer] Return code for options handeling
    # @param logger [Logger] system logger
    def self.execute_commands(options:, config:, logger:)
      command = options.command
      if ControllerCommands.simple_commands.keys.include?(command)
        params = ControllerCommands.simple_commands[command]
        params[:config] = config
        params[:logger] = logger
        ControllerCommands.simple_command(**params)
      else
        params = ControllerCommands.method(command.to_s).parameters.collect{|a|a[1]}
        args = {}
        params.each do |key|
          case key
          when :options
            args[:options] = options
          when :config
            args[:config] = config
          when :logger
            args[:logger] = logger
          end
        end
        ControllerCommands.send(command, args)
      end
    end
    private_class_method :execute_commands

    # Ensure that the selected device is accessable
    # @param options [Hash] The options hash
    # @param logger [Logger] system logger
    def self.check_devices(options:, config:, logger:)
      if options.device_command?
        ping = Net::Ping::External.new
        host = config.parsed[:device_config][:ip]
        return GOOD_DEVICE if ping.ping? host, 1, 0.2, 1
        return BAD_DEVICE if options[:device_given]
        config.raw[:devices].each_pair {|key, value|
          unless key == :default
            host = value[:ip]
            if ping.ping? host, 1, 0.2, 1
              config.parsed[:device_config] = value
              return CHANGED_DEVICE
            end
          end
        }
        return NO_DEVICES
      end
      return GOOD_DEVICE
    end
    private_class_method :check_devices

    # Configure the gem
    # @param options [Hash] The options hash
    # @return [Integer] Success or failure code
    # @param logger [Logger] system logger
    def self.configure(options:, logger:)
      if options[:configure]
        source_config = File.expand_path(File.join(File.dirname(__FILE__), "..", '..', 'config.json.example'))
        target_config = File.expand_path(options[:config])
        if File.exist?(target_config)
          unless options[:edit_params]
            return CONFIG_OVERWRITE
          end
        else
          ### Copy Config File ###
          FileUtils.copy(source_config, target_config)
        end
        if options[:edit_params]
          config = Config.new(options: options)
          config.load
          config.edit
        end
        return SUCCESS
      end
      nil
    end
    private_class_method :configure

    # Run a system command
    # @param command [String] The command to be run
    # @return [String] The output of the command
    def self.system(command:)
      `#{command}`.chomp
    end
  end
end
