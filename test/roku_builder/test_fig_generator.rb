
# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class FigGeneratorTest < Minitest::Test
    def setup
      Logger.set_testing
      @generator = FigGenerator.new()
    end

    def test_init
      assert  @generator != nil
    end

    def test_seperator
      @generator.seperator("Test String")
    end

    def test_generate_empty
      config = @generator.generate
      assert_match /const completionSpec: Fig.Spec = /, config
      assert_match /name: "roku"/, config
      puts config
    end

    def test_generator_subcommand
      @generator.mode(:command)
      @generator.on("-h", "--help", "Print Usage Info")
      config = @generator.generate
      assert_match /"subcommands":\[/, config

    end
  end
end
