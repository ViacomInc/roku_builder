# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class UtilTest < Minitest::Test
    def setup
      options = build_options
      @config = Config.new(options: options)
      @device_config = {
        ip: "111.222.333",
        user: "user",
        password: "password"
      }
      @config.instance_variable_set(:@parsed, {device_config: @device_config, init_params: {}})
    end
    def test_util_init
      test = UtilTestClass.new(config: @config)
      assert test.inited
    end
    def test_util_no_init
      UtilTestClass2.new(config: @config)
    end
  end

  class UtilTestClass < Util
    def init
      @inited = true
    end
    def inited
      @inited || false
    end
  end
  class UtilTestClass2 < Util
    def self.commands
    end
    def self.parse_options(option_parser:)
    end
  end
end

