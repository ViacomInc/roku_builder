# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class PackagerIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(PackagerIntergrationTest)
      @uuid = SecureRandom.uuid
      build_uuid_script
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
      cleanup_uuid_script
    end
    def test_package
      target = File.join(testfiles_path(PackagerIntergrationTest), "pkg.pkg")
      FileUtils.rm(target) if File.exist?(target)
      output = `#{roku} --package --stage production --out #{target}`
      refute_match(/WARN: Missing File/, output)
      wait_assert {File.exist?(target)}
      refute File.exist?(target+".zip")
      FileUtils.rm(target) if File.exist?(target)
    end
    def test_package_output
      target = File.join(testfiles_path(PackagerIntergrationTest), "pkg.pkg")
      FileUtils.rm(target) if File.exist?(target)
      output = `#{roku} --package --stage production --out #{target} -V`
      refute_match(/WARN: Missing File/, output)
      assert_match(/#{target}/, output)
      wait_assert {File.exist?(target)}
      refute File.exist?(target+".zip")
      FileUtils.rm(target) if File.exist?(target)
    end
    def test_package_no_key
      config = good_config(PackagerIntergrationTest)
      config[:projects][:project1][:stages][:production].delete(:key)
      @config = build_config(PackagerIntergrationTest, nil, config)
      target = File.join(testfiles_path(PackagerIntergrationTest), "pkg.pkg")
      FileUtils.rm(target) if File.exist?(target)
      output = `#{roku} --package --stage production --out #{target}`
      assert_match(/FATAL:.*Missing Key/, output)
    end
    def test_key
      target = File.join(testfiles_path(PackagerIntergrationTest), "pkg.pkg")
      `#{roku} --genkey --out #{target}`
      output = `#{roku} --key --stage production --debug`
      assert output =~ /-> e8efc6f5efd5b4991be53ccf3e273f04535bfb4c/
      FileUtils.rm(target) if File.exist?(target)
    end
    def test_genkey
      target = File.join(testfiles_path(PackagerIntergrationTest), "pkg.pkg")
      `#{roku} --genkey --out #{target}`
      wait_assert {File.exist?(target)}
      FileUtils.rm(target) if File.exist?(target)
    end
  end
end

