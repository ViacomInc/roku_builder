# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class LinkerIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(LinkerIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_deeplink
      `#{roku} --sideload --working`
      assert_log @uuid
      uuid_param = SecureRandom.uuid
      `#{roku} --deeplink 'uuid:#{uuid_param}'`
      assert_log uuid_param
    end
    def test_deeplink_with_sideload
      uuid_param = SecureRandom.uuid
      `#{roku} --deeplink 'uuid:#{uuid_param}' --working`
      assert_log @uuid
      assert_log uuid_param
    end
  end
end

