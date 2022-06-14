# ********** Copyright 2016 Viacom, Inc. Apache 2.0 **********

require "logger"
require "faraday"
require "faraday/digestauth"
require "pathname"
require "optparse"
require "pathname"
require "net/ping"
#config_manager
require 'json'
#stager
require 'pstore'
require "git"
#profiler
require 'nokogiri'
#navigator
require 'io/console'
#monitor
require 'readline'
#loader
require "net/telnet"
require "fileutils"
require "tempfile"
require "tmpdir"
require "zip"
#analyzer
require "image_size"


Dir.glob(File.join(File.dirname(__FILE__), "roku_builder", "*.rb")).each do |path|
  file = "roku_builder/"+File.basename(path, ".rb")
  require file
end

module RokuBuilder
  # Run the builder
  # @param options [Hash] The options hash
  def self.run(options: nil)
    @@options = nil
    @@testing ||= false
    setup_plugins
    setup_options(options: options)
    return unless @@options
    initialize_logger
    if @@options[:debug]
      execute
    else
      begin
        execute
      rescue StandardError => e
        Logger.instance.fatal "#{e.class}: #{e.message}"
        exit false unless @@testing
      end
    end
  end

  def self.setup_options(options:)
    begin
      @@options = Options.new(options: options)
      @@options.validate
    rescue InvalidOptions => e
      Logger.instance.fatal "#{e.class}: #{e.message}"
      @@options = nil
      return
    end
  end

  def self.execute
    load_config
    execute_command
  end

  def self.plugins
    @@plugins ||= []
  end

  def self.register_plugin(plugin)
    @@dev ||= false
    @@plugins ||= []
    @@plugins.delete(plugin) if @@dev
    @@plugins << plugin
  end

  def self.setup_plugins
    load_plugins
    process_plugins
    validate_plugins
  end

  def self.load_plugins
    Dir.glob(File.join(File.dirname(__FILE__), "roku_builder", "plugins", "*.rb")).each do |path|
      file = "roku_builder/plugins/"+File.basename(path, ".rb")
      require file
    end
    gem_versions = Gem::Specification.sort_by {|g| [g.name.downcase, g.version]}.group_by {|g| g.name}
    gems = []
    gem_versions.each {|v| gems.push(v.last.last)}
    gems.each do |gem|
      unless gem.name == "roku_builder"
        Dir.glob(File.join(gem.full_gem_path, "lib", "roku_builder", "plugins", "*")).each do |path|
          require path
        end
      end
    end
    load_dev_plugin
  end

  def self.load_dev_plugin
    dev_path = nil
    ARGV.each_index do |i|
      if ARGV[i] == "--dev-plugin"
        dev_path = ARGV[i+1]
        2.times {ARGV.delete_at(i)}
        break
      end
    end
    if dev_path
      @@dev = true
      Dir.glob(File.join(dev_path, "lib", "*.rb")).each do |path|
        require path
      end
      Dir.glob(File.join(dev_path, "lib", "roku_builder", "plugins", "*")).each do |path|
        require path
      end
      @@dev = false
    end
  end

  def self.process_plugins
    @@plugins ||= []
    @@plugins.sort! {|a,b| a.to_s <=> b.to_s}
    unless @@plugins.count == @@plugins.uniq.count
      duplicates = @@plugins.select{ |e| @@plugins.count(e) > 1  }.uniq
      raise ImplementationError, "Duplicate plugins: #{duplicates.join(", ")}"
    end
    @@plugins.each do |plugin|
      plugin.dependencies.each do |dependency|
        raise ImplementationError, "Missing dependency: #{dependency}" unless @@plugins.include?(dependency)
      end
      plugin.commands.keys.each do |command|
        raise ImplementationError, "Missing command method '#{command}' in #{plugin}" unless  plugin.instance_methods.include?(command)
      end
    end
  end

  def self.validate_plugins
    @@plugins.each do |plugin|
      plugin.validate
    end
  end

  def self.initialize_logger
    if @@options[:debug]
      Logger.set_debug
    elsif @@options[:verbose]
      Logger.set_info
    else
      Logger.set_warn
    end
  end

  def self.load_config
    @@config = Config.new(options: @@options)
    @@config.configure
    unless @@options[:configure] and not @@options[:edit_params]
      @@config.load
      @@config.validate
      @@config.parse
    end
  end

  def self.device_manager
    @@device_manager ||= DeviceManager.new(config: @@config, options: @@options)
  end

  def self.execute_command
    @@plugins.each do |plugin|
      if plugin.commands.keys.include?(@@options.command)
        stager = nil
        if plugin.commands[@@options.command][:stage]
          stager = Stager.new(config: @@config, options: @@options)
          stager.stage
        end
        instance = plugin.new(config: @@config)
        instance.send(@@options.command, **{options: @@options})
        stager.unstage if stager
      end
    end
  end

  # Parses a string into and options hash
  # @param options [String] string of options in the format "a:b, c:d"
  # @return [Hash] Options hash generated
  def self.options_parse(options:)
    parsed = {}
    opts = options.split(/,\s*/)
    opts.each do |opt|
      opt = opt.split(":")
      key = opt.shift.strip.to_sym
      value = opt.join(":").strip
      parsed[key] = value
    end
    parsed
  end

  def self.process_hook(hook:, params:)
    @@plugins.each do |plugin|
      if plugin.respond_to?("#{hook}_hook".to_sym)
        plugin.send("#{hook}_hook", **params)
      end
    end
  end

  # Run a system command
  # @param command [String] The command to be run
  # @return [String] The output of the command
  def self.system(command:)
    `#{command}`.chomp
  end

  def self.set_testing
    @@testing = true
    Logger.set_testing
  end
end
