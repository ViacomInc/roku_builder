# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class ProfilerIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(ProfilerIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_profile_stats
      `#{roku} --sideload --working`
      assert_log @uuid
      output = `#{roku} --profile stats`
      assert_match(/Name \| Count/, output)
      assert_match(/Total \|\s*5/, output)
      assert_match(/Default \|\s*1/, output)
      assert_match(/RectangleExample \|\s*1/, output)
      assert_match(/Poster \|\s*1/, output)
      assert_match(/Node \|\s*1/, output)
      assert_match(/Rectangle \|\s*1/, output)
    end
    def test_profile_all
      `#{roku} --sideload --working`
      assert_log @uuid
      output = `#{roku} --profile all`
      assert_match(/RectangleExample/, output)
    end
    def test_profile_roots
      `#{roku} --sideload --working`
      assert_log @uuid
      output = `#{roku} --profile roots`
      assert_match(/Default/, output)
    end
    def test_profile_node
      `#{roku} --sideload --working`
      assert_log @uuid
      output = `#{roku} --profile exampleRectangle`
      assert_match(/name="exampleRectangle"/, output)
    end
    def test_profile_images
      `#{roku} --sideload --working`
      assert_log @uuid
      output = `#{roku} --profile images`
      assert_match(/Available texture memory/, output)
    end
    def test_profile_textures
      `#{roku} --sideload --working`
      assert_log @uuid
      output = `#{roku} --profile textures`
      assert_match(/System textures/, output)
    end
  end
end
