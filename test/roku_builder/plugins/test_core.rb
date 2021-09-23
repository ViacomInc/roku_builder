# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class CoreTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Core)
    end
    def test_core_parse_options_long
      parser = OptionParser.new
      options = {}
      Core.parse_options(parser: parser, options: options)
      argv = ["roku", "--configure", "--validate", "--update-manifest", "--do-stage",
        "--do-unstage", "--edit", "params", "--config", "config-path",
        "--ref", "ref", "--working", "--current", "--stage", "stage", "--project",
        "project", "--out", "out", "--in", "in", "--device", "device",
        "--verbose", "--debug"]
      parser.parse! argv
      assert options[:configure]
      assert options[:validate]
      assert options[:increment]
      assert options[:dostage]
      assert options[:dounstage]
      assert_equal "params", options[:edit_params]
      assert_equal "config-path", options[:config]
      assert_equal "ref", options[:ref]
      assert options[:working]
      assert options[:current]
      assert_equal "stage", options[:stage]
      assert_equal "project", options[:project]
      assert_equal "out", options[:out]
      assert_equal "in", options[:in]
      assert_equal "device", options[:device]
      assert options[:device_given]
      assert options[:verbose]
      assert options[:debug]
    end
    def test_core_parse_options_short
      parser = OptionParser.new
      options = {}
      Core.parse_options(parser: parser, options: options)
      argv = ["roku", "-u", "-e", "params", "-r", "ref", "-w", "-c", "-s",
        "stage", "-p", "project",  "-O", "out", "-I", "in", "-D", "device", "-V"]
      parser.parse! argv
      assert options[:increment]
      assert_equal "params", options[:edit_params]
      assert_equal "ref", options[:ref]
      assert options[:working]
      assert options[:current]
      assert_equal "stage", options[:stage]
      assert_equal "project", options[:project]
      assert_equal "out", options[:out]
      assert_equal "in", options[:in]
      assert_equal "device", options[:device]
      assert options[:device_given]
      assert options[:verbose]
    end
    def test_core_configure
      logger = Minitest::Mock.new
      options = {configure: true, config: File.join(test_files_path(CoreTest), "config.json")}
      config, options = build_config_options_objects(CoreTest, options, false)
      logger.expect(:unknown, nil, ["Configured"])
      Logger.class_variable_set(:@@instance, logger)
      core = Core.new(config: config)
      core.configure(options: options)
      logger.verify
    end
    def test_core_validate
      logger = Minitest::Mock.new
      config, options = build_config_options_objects(CoreTest, {validate: true}, false)
      logger.expect(:unknown, nil, ["Config Validated"])
      Logger.class_variable_set(:@@instance, logger)
      core = Core.new(config: config)
      core.validate(options: options)
      logger.verify
    end
    def test_core_increment
      config, options = build_config_options_objects(CoreTest, {increment: true, working: true}, false)
      source = File.join(test_files_path(CoreTest), "manifest_template")
      target = File.join(test_files_path(CoreTest), "manifest")
      FileUtils.cp(source, target)
      core = Core.new(config: config)
      Time.stub(:now, Time.new(2001, 02, 01)) do
        core.increment(options: options)
      end
      assert_equal "020101.2", Manifest.new(config: config).build_version
      FileUtils.rm(target)
    end
    def test_core_dostage
      stager = Minitest::Mock.new
      config, options = build_config_options_objects(CoreTest, {increment: true, working: true}, false)
      stager.expect(:stage, nil)
      core = Core.new(config: config)
      Stager.stub(:new, stager) do
        core.dostage(options: options)
      end
    end
    def test_core_dounstage
      stager = Minitest::Mock.new
      config, options = build_config_options_objects(CoreTest, {increment: true, working: true}, false)
      stager.expect(:unstage, nil)
      core = Core.new(config: config)
      Stager.stub(:new, stager) do
        core.dounstage(options: options)
      end
    end
    def test_core_help
      parser = OptionParser.new
      options = {}
      help_text = Core.get_help_text(parser: parser, options: options, plugin_name: nil)
      assert help_text
    end
    def test_core_help_plugin
      parser = OptionParser.new
      options = {}
      help_text = Core.get_help_text(parser: parser, options: options, plugin_name: "Loader")
      assert help_text
    end
    def test_core_get_plugin_by_name
      parser = OptionParser.new
      options = {}
      plugin_name = Core.get_plugin_by_name("core")
      refute_nil plugin_name
      assert_match "RokuBuilder::Core", plugin_name.to_s
    end
  end
end

