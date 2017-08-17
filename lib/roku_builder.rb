# ********** Copyright 2016 Viacom, Inc. Apache 2.0 **********

require "logger"
require "faraday"
require "faraday/digestauth"
require "pathname"
require "rubygems"
require "optparse"
require "pathname"
require "net/ping"
#config_manager
require 'json'
#stager
require 'pstore'
require "git"
#profiler
require 'oga'
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


Dir.glob(File.join(File.dirname(__FILE__), "roku_builder", "*.rb")).each do |path|
  file = "roku_builder/"+File.basename(path, ".rb")
  require file
end

module RokuBuilder
  # Run the builder
  # @param options [Hash] The options hash
  def self.run(options: nil)
    @@options = nil
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
    check_devices
    execute_command
  end

  def self.plugins
    @@plugins ||= []
  end

  def self.register_plugin(plugin)
    @@plugins ||= []
    @@plugins << plugin
  end

  def self.setup_plugins
    load_plugins
    process_plugins
  end

  def self.load_plugins
    Dir.glob(File.join(File.dirname(__FILE__), "roku_builder", "plugins", "*.rb")).each do |path|
      file = "roku_builder/plugins/"+File.basename(path, ".rb")
      require file
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

  def self.check_devices
    if @@options.device_command?
      ping = Net::Ping::External.new
      host = @@config.parsed[:device_config][:ip]
      return if ping.ping? host, 1, 0.2, 1
      raise DeviceError, "Device not online" if @@options[:device_given]
      @@config.raw[:devices].each_pair {|key, value|
        unless key == :default
          host = value[:ip]
          if ping.ping? host, 1, 0.2, 1
            @@config.parsed[:device_config] = value
            Logger.instance.warn("Default device offline, choosing Alternate")
            return
          end
        end
      }
      raise DeviceError, "No devices found"
    end
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
        instance.send(@@options.command, {options: @@options})
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
      key = opt.shift.to_sym
      value = opt.join(":")
      parsed[key] = value
    end
    parsed
  end

  # Run a system command
  # @param command [String] The command to be run
  # @return [String] The output of the command
  def self.system(command:)
    `#{command}`.chomp
  end
end
