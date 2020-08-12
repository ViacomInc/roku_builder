# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class Core
    extend Plugin

    def self.commands
      {
        configure: {},
        validate: {},
        increment: {source: true, stage: true},
        dostage: {source: true},
        dounstage: {source: true}
      }
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("--configure", "Copy base configuration file to the --config location. Default: '~/.roku_config.json'") do
        options[:configure] = true
      end
      parser.on("--validate", "Validate configuration") do
        options[:validate] = true
      end
      parser.on("-u", "--update-manifest", "Increment manifest build version") do
        options[:increment] = true
      end
      parser.on("--do-stage", "Run the stager. Used for scripting. Always run --do-unstage after") do
        options[:dostage] = true
      end
      parser.on("--do-unstage", "Run the unstager. Used for scripting. Always run --do-script first") do
        options[:dounstage] = true
      end
      parser.separator ""
      parser.separator "Config Options:"
      parser.on("-e", "--edit PARAMS", "Edit config params when configuring. (eg. a:b, c:d,e:f)") do |p|
        options[:edit_params] = p
      end
      parser.on("--config CONFIG", "Set a custom config file. Default: '~/.roku_config.json'") do |c|
        options[:config] = c
      end
      parser.separator ""
      parser.separator "Source Options:"
      parser.on("-r", "--ref REF", "Git referance to use for sideloading") do |r|
        options[:ref] = r
      end
      parser.on("-w", "--working", "Use working directory to sideload or test") do
        options[:working] = true
      end
      parser.on("-c", "--current", "Use current directory to sideload or test. Overrides any project config") do
        options[:current] = true
      end
      parser.on("-s", "--stage STAGE", "Set the stage to use. Default: 'production'") do |b|
        options[:stage] = b
      end
      parser.on("-P", "--project ID", "Use a different project") do |p|
        options[:project] = p
      end
      parser.separator ""
      parser.separator "Other Options:"
      parser.on("-O", "--out PATH", "Output file/folder. If PATH ends in .pkg/.zip/.jpg, file is assumed, otherwise folder is assumed") do |o|
        options[:out] = o
      end
      parser.on("-I", "--in PATH", "Input file for sideloading") do |i|
        options[:in] = i
      end
      parser.on("-D", "--device ID", "Use a different device corresponding to the given ID") do |d|
        options[:device] = d
        options[:device_given] = true
      end
      parser.on("-V", "--verbose", "Print Info message") do
        options[:verbose] = true
      end
      parser.on("--debug", "Print Debug messages") do
        options[:debug] = true
      end
      parser.on("-h", "--help [PLUGIN]", "Show help") do |h|
        help_text = self.get_help_text(parser: parser, options: options, plugin_name: h)
        puts help_text
        exit
      end
      parser.on("-v", "--version", "Show version") do
        puts RokuBuilder::VERSION
        exit
      end
    end

    def initialize(config:)
      @config = config
    end

    def configure(options:)
      # Stub command
      # Handled in the config class
      Logger.instance.unknown "Configured"
    end
    def validate(options:)
      # Stub command
      # Handled in the config class
      Logger.instance.unknown "Config Validated"
    end
    def increment(options:)
      manifest = Manifest.new(config: @config)
      old = manifest.build_version
      manifest.increment_build_version
      new = manifest.build_version
      Logger.instance.info "Update build version from:\n#{old}\nto:\n#{new}"
    end
    def dostage(options:)
      Stager.new(config: @config, options: options).stage
    end
    def dounstage(options:)
      Stager.new(config: @config, options: options).unstage
    end

    def self.get_help_text(parser:, options:, plugin_name:)
      plugin = self.get_plugin_by_name(plugin_name)
      puts parser
      if nil == plugin
        return parser.to_s
      else
        pluginParser = OptionParser.new
        pluginParser.separator ""
        pluginParser.separator "Options for #{plugin}:"
        plugin.parse_options(parser: pluginParser, options: options)
        return pluginParser.to_s
      end
    end

    def self.get_plugin_by_name(name)
      if name.nil?
        return nil
      end
      pluginIndex = RokuBuilder.plugins.map{|pluginClass| pluginClass.name.split('::').last().downcase}.index(name.downcase)
      if !pluginIndex.nil?
        plugin = RokuBuilder.plugins[pluginIndex]
        return plugin
      end
    end
  end
  RokuBuilder.register_plugin(Core)
end
