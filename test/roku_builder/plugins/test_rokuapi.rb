# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class RokuAPITest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(RokuAPI)
    end

    def test_commands
      commands = RokuAPI.commands
      refute_nil commands[:submit]
      refute_nil commands[:publish]
    end

    def test_parse_options
      parser = OptionParser.new
      options = {}
      RokuAPI.parse_options(parser: parser, options: options)
      argv = ["roku", "--submit", "--publish"]
      parser.parse! argv
      assert options[:submit]
      assert options[:publish]
    end

    def test_dependencies
      assert_kind_of Array, RokuAPI.dependencies
      assert_equal RokuAPI.dependencies.count, 0
    end


  end
end
