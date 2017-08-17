# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder
  class Options < Hash
    def initialize(options: nil)
      @logger = Logger.instance
      setup_plugin_commands
      options ||= parse
      merge!(options)
    end

    def validate
      validate_commands
      validate_sources
      validate_deprivated
    end

    def command
      (keys & commands).first
    end

    def exclude_command?
      exclude_commands.include?(command)
    end

    def source_command?
      source_commands.include?(command)
    end

    def device_command?
      device_commands.include?(command)
    end

    def has_source?
      !(keys & sources).empty?
    end

    private

    def setup_plugin_commands
      RokuBuilder.plugins.each do |plugin|
        plugin.commands.each do |command, attributes|
          commands << command
          [:device, :source, :exclude].each do |type|
            if attributes[type]
              send("#{type}_commands".to_sym) << command
            end
          end
        end
      end
    end

    def parse
      options = {}
      options[:config] = '~/.roku_config.json'
      options[:update_manifest] = false
      parser = OptionParser.new
      parser.banner = "Usage: roku <command> [options]"
      add_plugin_options(parser: parser, options:options)
      validate_parser(parser: parser)
      parser.parse!
      options
    end

    def add_plugin_options(parser:, options:)
      RokuBuilder.plugins.each do |plugin|
        parser.separator ""
        parser.separator "Options for #{plugin}:"
        plugin.parse_options(parser: parser, options: options)
      end
    end

    def validate_parser(parser:)
      short = []
      long = []
      stack = parser.instance_variable_get(:@stack)
      stack.each do |optionsList|
        optionsList.each_option do |option|
          if option.respond_to?(:short)
            if short.include?(option.short.first)
              raise ImplementationError, "Duplicate short option defined: #{option.short.first}"
            end
            short.push(option.short.first) if option.short.first
            if long.include?(option.long.first)
              raise ImplementationError, "Duplicate long option defined: #{option.long.first}"
            end
            long.push(option.long.first) if option.long.first
          end
        end
      end
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
      @commands ||= []
    end

    # List of depricated options
    # @return [Hash] Hash of depricated options and the warning message for each
    def depricated_options
      @depricated_options ||= {}
    end

    # List of source options
    # @return [Array<Symbol>] List of source symbols that can be used in the options hash
    def sources
      [:ref, :stage, :working, :current, :in]
    end

    # List of commands requiring a source option
    # @return [Array<Symbol>] List of command symbols that require a source in the options hash
    def source_commands
      @source_commands ||= []
    end

    # List of commands the activate the exclude files
    # @return [Array<Symbol] List of commands the will activate the exclude files lists
    def exclude_commands
      @exclude_commands ||= []
    end

    # List of commands that require a device
    # @return [Array<Symbol>] List of commands that require a device
    def device_commands
      @device_commands ||= []
    end
  end
end
