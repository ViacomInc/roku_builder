# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class ScripterIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(ScripterIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_print_root_dir
      output = `#{roku} --print root_dir --working`
      assert_equal testfiles_path(ScripterIntergrationTest), output
    end
    def test_print_app_name
      output = `#{roku} --print app_name --working`
      assert_equal "App Name", output
    end
    def test_print_title
      output = `#{roku} --print title --working`
      assert_equal "Rectangle Example", output
    end
    def test_print_build_version
      output = `#{roku} --print build_version --working`
      assert_equal "00000", output
    end
    def test_print_app_version
      output = `#{roku} --print app_version --working`
      assert_equal "1.0", output
    end
  end
end
