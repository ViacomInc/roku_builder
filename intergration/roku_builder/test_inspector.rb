# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class InspectorIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(InspectorIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_inspector
      target = File.join(testfiles_path(InspectorIntergrationTest), "test.pkg")
      output = `bin/roku --inspect --in #{target} --password CvOqcutO3X419INdUbOyqw== --config #{@config}`
      assert output =~ /App Name:/
      assert output =~ /Dev ID:/
      assert output =~ /Creation Date:/
      assert output =~ /dev.zip:/
    end
    def test_screencapture
      target = File.join(testfiles_path(InspectorIntergrationTest), "out.jpg")
      `#{roku} --sideload --working`
      assert_log @uuid
      `#{roku} --screencapture --out #{target}`
      wait_assert(15) {File.exist?(target)}
      FileUtils.rm(target)
    end
  end
end

