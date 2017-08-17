# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class NavigatorIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(NavigatorIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_nav
      skip("To be implemented later")
    end
    def test_navigate
      skip("To be implemented later")
    end
    def test_type
      skip("To be implemented later")
    end
    def test_screen
      skip("To be implemented later")
    end
    def test_screens
      skip("To be implemented later")
    end
  end
end

