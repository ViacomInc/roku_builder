# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class ConfigTest < Minitest::Test
    def setup
      Logger.set_testing
    end

    def test_config_init
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
    end

    def test_config_expand_path
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      options[:config].sub!(/#{File.expand_path("~")}/, "~")
        config = Config.new(options: options)
      config.load
    end

    def test_missing_config
      options = build_options({config: File.join(test_files_path(ConfigTest), "missing.json"), validate: true})
      assert_raises ArgumentError do
        config = Config.new(options: options)
        config.load
      end
    end

    def test_invalid_config
      options = build_options({config: File.join(test_files_path(ConfigTest), "bad.json"), validate: true})
      assert_raises InvalidConfig do
        config = Config.new(options: options)
        config.load
        config.validate
      end
    end

    def test_non_json_config
      options = build_options({config: File.join(test_files_path(ConfigTest), "non_json.json"), validate: true})
      assert_raises InvalidConfig do
        config = Config.new(options: options)
        config.load
      end
    end

    def test_config_parse
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
      config.parse
      assert_equal Hash, config.parsed.class
    end

    def test_config_read
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
      assert_equal :roku, config.raw[:devices][:default]
      assert_equal :p1, config.raw[:projects][:default]
    end

    def test_config_read_parent_child_part
      options = build_options({config: File.join(test_files_path(ConfigTest), "child.json"), validate: true})
      config = Config.new(options: options)
      config.load
      assert_equal :roku, config.raw[:devices][:default]
      assert_equal :p1, config.raw[:projects][:default]
    end

    def test_config_read_parent_parent_part
      options = build_options({config: File.join(test_files_path(ConfigTest), "parent_projects.json"), validate: true})
      config = Config.new(options: options)
      config.load
      assert_equal "app", config.raw[:projects][:p1][:app_name]
    end

    def test_config_edit
      orginal = File.join(test_files_path(ConfigTest), "config.json")
      tmp = File.join(test_files_path(ConfigTest), "tmpconfig.json")
      FileUtils.cp(orginal, tmp)
      options = build_options({config: tmp, edit_params: "ip:123.456.789", validate: true})
      config = Config.new(options: options)
      config.load
      config.edit
      options = build_options({config: tmp, validate: true})
      config = Config.new(options: options)
      config.load
      assert_equal "123.456.789", config.raw[:devices][:roku][:ip]
      FileUtils.rm(tmp)
    end

    def test_config_configure_creation
      target_config = File.join(test_files_path(ConfigTest), "configure_test.json")
      options = build_options({config: target_config, configure: true})
      File.delete(target_config) if File.exist?(target_config)
      refute File.exist?(target_config)
      config = Config.new(options: options)
      config.configure
      assert File.exist?(target_config)
      File.delete(target_config) if File.exist?(target_config)
    end

    def test_config_configure_edit_params
      target_config = File.join(test_files_path(ConfigTest), "configure_test.json")
      options = build_options({
        config: target_config,
        configure: true,
        edit_params: "ip:111.222.333.444"
      })
      File.delete(target_config) if File.exist?(target_config)
      refute File.exist?(target_config)
      config = Config.new(options: options)
      config.configure
      assert File.exist?(target_config)
      assert_equal "111.222.333.444", config.raw[:devices][config.raw[:devices][:default]][:ip]
      File.delete(target_config) if File.exist?(target_config)
    end

    def test_config_configure_edit_params_project
      target_config = File.join(test_files_path(ConfigTest), "configure_test.json")
      options = build_options({
        config: target_config,
        configure: true,
        edit_params: "directory:/test/dir"
      })
      File.delete(target_config) if File.exist?(target_config)
      refute File.exist?(target_config)
      config = Config.new(options: options)
      config.configure
      assert File.exist?(target_config)
      assert_equal "/test/dir", config.raw[:projects][config.raw[:projects][:default]][:directory]
      File.delete(target_config) if File.exist?(target_config)
    end

    def test_config_configure_edit_params_stage
      target_config = File.join(test_files_path(ConfigTest), "configure_test.json")
      options = build_options({
        config: target_config,
        configure: true,
        edit_params: "branch:test"
      })
      File.delete(target_config) if File.exist?(target_config)
      refute File.exist?(target_config)
      config = Config.new(options: options)
      config.configure
      assert File.exist?(target_config)
      assert_equal "test", config.raw[:projects][config.raw[:projects][:default]][:stages][:production][:branch]
      File.delete(target_config) if File.exist?(target_config)
    end

    def test_config_configure_edit_params_default
      target_config = File.join(test_files_path(ConfigTest), "configure_test.json")
      options = build_options({
        config: target_config,
        configure: true
      })
      File.delete(target_config) if File.exist?(target_config)
      refute File.exist?(target_config)
      config = Config.new(options: options)
      config.configure
      assert File.exist?(target_config)
      assert_raises InvalidOptions do
        config.configure
      end
      File.delete(target_config) if File.exist?(target_config)
    end

    def test_config_set_root_dir
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
      config.parse
      config.root_dir = "new/dir"
      assert_equal "new/dir", config.root_dir
    end

    def test_config_set_in
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
      config.parse
      config.in = "new/dir"
      assert_equal "new/dir", config.in
    end

    def test_config_set_out
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
      config.parse
      config.out = "new/dir"
      assert_equal "new/dir", config.out
    end

    def test_config_dont_set_params
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
      config.parse
      assert_raises StandardError do
        config.param = "value"
      end
    end
    def test_config_input_mappings
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)
      config.load
      config.parse
      refute_nil config.input_mappings
      assert_equal ["home", "Home"], config.input_mappings[:a]
    end
  end
end
