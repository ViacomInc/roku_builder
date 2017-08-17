# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class CoreIntergrationTest < Minitest::Test
    include Helpers
    def setup
      @config = build_config(CoreIntergrationTest)
    end
    def teardown
      FileUtils.rm(@config) if File.exist?(@config)
    end
    def test_configure
      config = File.join(testfiles_path(CoreIntergrationTest), "configure.json")
      FileUtils.rm(config) if File.exist?(config)
      output = `bin/roku --configure --config #{config}`
      assert File.exist?(config)
      assert output =~ /Configured/
      FileUtils.rm(config) if File.exist?(config)
    end
    def test_validate
      output = `bin/roku --validate --config #{@config}`
      assert output =~ /Validated/
    end
    def test_validate_bad
      config = good_config(CoreIntergrationTest)
      config[:devices][:roku].delete(:ip)
      config = build_config(CoreIntergrationTest, "config.json", config)
      output = `bin/roku --validate --config #{config}`
      assert output =~ /IP address/
      assert output =~ /Invalid/
    end
    def test_update_manifest
      target = File.join(testfiles_path(CoreIntergrationTest), "manifest")
      source = File.join(testfiles_path(CoreIntergrationTest), "manifest_template")
      FileUtils.cp source, target
      `bin/roku --update-manifest --working --config #{@config}`
      refute FileUtils.compare_file(source, target)
      FileUtils.rm target
    end
    def test_stage_unstage
      target = File.join(testfiles_path(CoreIntergrationTest), "file.tmp")
      refute File.exist?(target)
      `bin/roku --do-stage --stage production --config #{@config}`
      assert File.exist?(target)
      `bin/roku --do-unstage --stage production --config #{@config}`
      refute File.exist?(target)
    end
  end
end

