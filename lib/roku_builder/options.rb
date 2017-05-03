# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder
  class Options < Hash
    def initialize(options: options)
      merge!(options)
      @logger = Logger.instance
      validate
    end

    def command
      (keys & commands).first
    end

    def exclude_command?
      exclude_commands.include?(command)
    end

    def source_command?
      (source_commands & keys).count > 0
    end

    def device_command?
      device_commands.include?(command)
    end

    def has_source?
      !(keys & sources).empty?
    end

    private

    def validate
      validate_commands
      validate_sources
      validate_combinations
      validate_deprivated
    end

    def validate_commands
      all_commands = keys & commands
      raise InvalidOptions, "Only specify one command" if all_commands.count > 1
      raise InvalidOptions, "Specify at least one command" if all_commands.count < 1
    end

    def validate_sources
      all_sources = keys & sources
      raise InvalidOptions, "Only spefify one source" if all_sources.count > 1
      if source_command? and !has_source?
        raise InvalidOptions, "Must specify a source for that command"
      end
    end

    def validate_combinations
      all_sources = keys & sources
      if all_sources.include?(:current) and not (self[:build] or self[:sideload])
        raise InvalidOptions, "Current source onle works for build or sideload"
      end
      if self[:in] and not self[:sideload]
        raise InvalidOptions, "In source only works for sideloading"
      end
    end

    def validate_deprivated
      depricated = keys & depricated_options.keys
      if depricated.count > 0
        depricated.each do |key|
          @logger.warn depricated_options[key]
        end
      end
    end

    # List of command options
    # @return [Array<Symbol>] List of command symbols that can be used in the options hash
    def commands
      [:sideload, :package, :test, :deeplink,:configure, :validate, :delete,
        :navigate, :navigator, :text, :build, :monitor, :update, :screencapture,
        :key, :genkey, :screen, :screens, :applist, :print, :profile, :dostage,
        :dounstage]
    end

    # List of depricated options
    # @return [Hash] Hash of depricated options and the warning message for each
    def depricated_options
      {deeplink_depricated: "-L and --deeplink are depricated. Use -o or --deeplink-options." }
    end

    # List of source options
    # @return [Array<Symbol>] List of source symbols that can be used in the options hash
    def sources
      [:ref, :set_stage, :working, :current, :in]
    end

    # List of commands requiring a source option
    # @return [Array<Symbol>] List of command symbols that require a source in the options hash
    def source_commands
      [:sideload, :package, :test, :build, :key, :update, :print]
    end

    # List of commands the activate the exclude files
    # @return [Array<Symbol] List of commands the will activate the exclude files lists
    def exclude_commands
      [:build, :package]
    end

    # List of commands that require a device
    # @return [Array<Symbol>] List of commands that require a device
    def device_commands
      [:sideload, :package, :test, :deeplink, :delete, :navigate, :navigator,
        :text, :monitor, :screencapture, :applist, :profile, :key, :genkey ]
    end
  end
end
