# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class OptionsPluginTest < Minitest::Test
    def setup
      Logger.set_testing
    end
    def test_options_plugins_parse
      RokuBuilder.class_variable_set(:@@plugins, nil)
      parser = Minitest::Mock.new()
      options_hash = {}
      RokuBuilder.register_plugin( OptionsTestPlugin)
      options = Options.allocate
      parser.expect(:parse!, nil)
      parser.expect(:banner=, nil, [String])
      parser.expect(:separator, nil, [String])
      parser.expect(:separator, nil, [String])
      OptionParser.stub(:new, parser) do
        options.stub(:validate_parser, nil) do
          options_hash = options.send(:parse)
        end
      end
      assert options_hash[:run]
      parser.verify
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      assert_includes options.send(:commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands_source
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      assert_includes options.send(:source_commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands_device
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      assert_includes options.send(:device_commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands_exclude
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      assert_includes options.send(:exclude_commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands_basic
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin2)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      assert_includes options.send(:commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands_source_2
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin2)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      refute_includes options.send(:source_commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands_device_2
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin2)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      refute_includes options.send(:device_commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
    def test_options_plugins_commands_exclude_2
      RokuBuilder.class_variable_set(:@@plugins, nil)
      RokuBuilder.register_plugin(OptionsTestPlugin2)
      options = Options.allocate
      options.send(:setup_plugin_commands)
      refute_includes options.send(:exclude_commands), :test
      RokuBuilder.class_variable_set(:@@plugins, nil)
    end
  end
  class OptionsTestPlugin
    extend Plugin
    def self.parse_options(parser:, options:)
      options[:run] = true
    end
    def self.commands
      {test: {device: true, source: true, exclude: true}}
    end
  end
  class OptionsTestPlugin2
    extend Plugin
    def self.parse_options(parser:, options:)
    end
    def self.commands
      {test: {}}
    end
  end
end
