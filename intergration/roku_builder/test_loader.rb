# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class LoaderIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(LoaderIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_sideload
      output = `#{roku} --sideload --stage production`
      assert_log @uuid
      refute_match(/WARN: Missing File/, output)
    end
    def test_delete
      `#{roku} --sideload --working`
      assert_log @uuid
      `#{roku} --delete`
      output = `#{roku} --app-list`
      refute_match(/\|\s*dev\s*\|/, output)
    end
    def test_build
      target = File.join(testfiles_path(LoaderIntergrationTest), "out.zip")
      FileUtils.rm(target) if File.exist?(target)
      `#{roku} --build --working --out #{target}`
      assert File.exist?(target)
      FileUtils.rm(target) if File.exist?(target)
    end
  end
end

