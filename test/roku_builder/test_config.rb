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

    def test_config_read_repeat_stages
      options = build_options({config: File.join(test_files_path(ConfigTest), "repeat_stages.json"), validate: true})
      config = Config.new(options: options)
      config.load
      assert_equal "stage_script a", config.raw[:projects][:p1][:stages][:a][:script][:stage]
      assert_equal "stage_script b", config.raw[:projects][:p1][:stages][:b][:script][:stage]
      assert_equal "unstage_script", config.raw[:projects][:p1][:stages][:a][:script][:unstage]
      assert_equal "key", config.raw[:projects][:p1][:stages][:a][:key]
      assert_nil config.raw[:projects][:p1][:stages][:"!repeat"]
    end

    def test_config_read_repeat_multi_stages
      options = build_options({config: File.join(test_files_path(ConfigTest), "repeat_multi_stages.json"), validate: true})
      config = Config.new(options: options)
      config.load
      assert_equal "stage_script a", config.raw[:projects][:p1][:stages][:a][:script][:stage]
      assert_equal "stage_script b", config.raw[:projects][:p1][:stages][:b][:script][:stage]
      assert_equal "stage_script a", config.raw[:projects][:p1][:stages][:a_2][:script][:stage]
      assert_equal "stage_script b", config.raw[:projects][:p1][:stages][:b_2][:script][:stage]
      assert_nil config.raw[:projects][:p1][:stages][:"!repeat"]
    end

    def test_config_read_multi_repeat_stages
      options = build_options({config: File.join(test_files_path(ConfigTest), "multi_repeat_stages.json"), validate: true})
      config = Config.new(options: options)
      config.load
      assert_equal "stage_script a", config.raw[:projects][:p1][:stages][:a][:script][:stage]
      assert_equal "stage_script b", config.raw[:projects][:p1][:stages][:b][:script][:stage]
      assert_equal "stage_script2 c", config.raw[:projects][:p1][:stages][:c][:script][:stage]
      assert_equal "stage_script2 d", config.raw[:projects][:p1][:stages][:d][:script][:stage]
      assert_nil config.raw[:projects][:p1][:stages][:"!repeat_1"]
      assert_nil config.raw[:projects][:p1][:stages][:"!repeat_2"]
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

    def test_config_read_local
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)

      mock = Minitest::Mock.new
      io = proc { |path|
        if path == './.roku_config.json'
          mock
        else
          IO.new(IO.sysopen(path))
        end
      }
      local_config_content = IO.read(File.join(test_files_path(ConfigTest), "local.json"))
      mock.expect(:read, local_config_content)

      File.stub(:exist?, true) do
        File.stub(:open, io) do
          config.load
        end
      end

      mock.verify
      refute_nil config.raw[:projects][:p2]
      assert_equal "app2", config.raw[:projects][:p2][:app_name]
    end

    def test_config_read_local_directory
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)

      mock = Minitest::Mock.new
      io = proc { |path|
        if path == './.roku_config.json'
          mock
        else
          IO.new(IO.sysopen(path))
        end
      }
      local_config_content = IO.read(File.join(test_files_path(ConfigTest), "local.json"))
      mock.expect(:read, local_config_content)

      File.stub(:exist?, true) do
        File.stub(:open, io) do
          config.load
        end
      end

      mock.verify
      refute_nil config.raw[:projects][:p2]
      assert_equal `pwd`.chomp, config.raw[:projects][:p2][:directory]
    end

    def test_config_read_local_sub_config
      options = build_options({config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
      config = Config.new(options: options)

      mock = Minitest::Mock.new
      io = proc { |path|
        if path == './.roku_config.json' or path == "keys.json"
          mock
        else
          IO.new(IO.sysopen(path))
        end
      }
      local_config_content = IO.read(File.join(test_files_path(ConfigTest), "local.json"))
      mock.expect(:read, local_config_content)
      local_sub_config_content = IO.read(File.join(test_files_path(ConfigTest), "local_sub.json"))
      mock.expect(:read, local_sub_config_content)

      File.stub(:exist?, true) do
        File.stub(:open, io) do
          Dir.stub(:glob, ["keys.json"]) do
            config.load
          end
        end
      end

      mock.verify
      refute_nil config.raw[:keys]
      refute_nil config.raw[:keys][:test_key]
      assert_equal "password", config.raw[:keys][:test_key][:password]
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
    def test_config_no_default_device
      options = build_options({config: File.join(test_files_path(ConfigTest), "no_default_project.json"), validate: true})
      config = Config.new(options: options)
      config.load
    end
    def test_config_no_default_project
      options = build_options({config: File.join(test_files_path(ConfigTest), "no_default_device.json"), validate: true})
      config = Config.new(options: options)
      config.load
    end
  end
end
