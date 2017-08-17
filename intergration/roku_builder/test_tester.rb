# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class TesterIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(TesterIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_test
      skip("To be implemented later")
    end
  end
end
