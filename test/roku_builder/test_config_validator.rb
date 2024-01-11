# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class ConfigValidatorTest < Minitest::Test
    def setup
      Logger.set_testing
    end

    def test_config_manager_validate_devices
      config = good_config
      config[:devices] = nil
      validator = ConfigValidator.new(config: config)
      assert validator.is_fatal?
      assert_equal [1], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_devices_default
      config = good_config
      config[:devices][:default] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [2], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_devices_default_is_symbol
      config = good_config
      config[:devices][:default] = "bad"
      validator = ConfigValidator.new(config: config)
      assert_equal [3], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_ip
      config = good_config
      config[:devices][:roku][:ip] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [7], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_ip_empty
      config = good_config
      config[:devices][:roku][:ip] = ""
      validator = ConfigValidator.new(config: config)
      assert_equal [7], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_ip_default_value
      config = good_config
      config[:devices][:roku][:ip] = "xxx.xxx.xxx.xxx"
      validator = ConfigValidator.new(config: config)
      assert_equal [7], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_user
      config = good_config
      config[:devices][:roku][:user] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [8], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_user_empty
      config = good_config
      config[:devices][:roku][:user] = ""
      validator = ConfigValidator.new(config: config)
      assert_equal [8], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_user_default_value
      config = good_config
      config[:devices][:roku][:user] = "<username>"
      validator = ConfigValidator.new(config: config)
      assert_equal [8], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_password
      config = good_config
      config[:devices][:roku][:password] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [9], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_password_empty
      config = good_config
      config[:devices][:roku][:password] = ""
      validator = ConfigValidator.new(config: config)
      assert_equal [9], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_device_password_default_value
      config = good_config
      config[:devices][:roku][:password] = "<password>"
      validator = ConfigValidator.new(config: config)
      assert_equal [9], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_projects
      config = good_config
      config[:projects] = nil
      validator = ConfigValidator.new(config: config)
      assert validator.is_valid?
    end

    def test_config_manager_validate_projects_default_default_value
      config = good_config
      config[:projects][:default] = "<project id>".to_sym
      validator = ConfigValidator.new(config: config)
      assert_equal [5], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_projects_default_is_symbol
      config = good_config
      config[:projects][:default] = "project_id"
      validator = ConfigValidator.new(config: config)
      assert_equal [6], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_app_name
      config = good_config
      config[:projects][:project1][:app_name] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [10], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_directory
      config = good_config
      config[:projects][:project1][:directory] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [11], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_folders
      config = good_config
      config[:projects][:project1][:files] = ["manifest"]
      config[:projects][:project1][:folders] = nil
      config[:projects][:project1][:source_files] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [14, -1], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_folders_is_array
      config = good_config
      config[:projects][:project1][:folders] = "Folders"
      validator = ConfigValidator.new(config: config)
      assert_equal [13, -1], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_files
      config = good_config
      config[:projects][:project1][:files] = nil
      config[:projects][:project1][:folders] = ["images", "source"]
      config[:projects][:project1][:source_files] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [14, -1], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_source_files
      config = good_config
      config[:projects][:project1][:source_files] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [14], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_filess_is_array
      config = good_config
      config[:projects][:project1][:files] = "Files"
      validator = ConfigValidator.new(config: config)
      assert_equal [15, -1], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_keys_pkg
      config = good_config
      config[:keys][:a][:keyed_pkg] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [19], validator.instance_variable_get(:@codes)
      config = good_config
      config[:keys][:a][:keyed_pkg] = "<path/to/signed/package>"
      validator = ConfigValidator.new(config: config)
      assert_equal [19], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_keys_password
      config = good_config
      config[:keys][:a][:password] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [20], validator.instance_variable_get(:@codes)
      config = good_config
      config[:keys][:a][:password] = "<password>"
      validator = ConfigValidator.new(config: config)
      assert_equal [20], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_input_mappings
      config = good_config
      config[:input_mappings]["a"] = ["home"]
      validator = ConfigValidator.new(config: config)
      assert_equal [21], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_stage_method_bad
      config = good_config
      config[:projects][:project2][:stage_method] = :bad
      validator = ConfigValidator.new(config: config)
      assert_equal [18], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_stage_method_missing
      config = good_config
      config[:projects][:project2][:stage_method] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [23], validator.instance_variable_get(:@codes)
    end

    def test_config_manager_validate_project_missing_plugin
      config = good_config
      config[:projects][:project2][:stage_method] = :plugin
      validator = ConfigValidator.new(config: config)
      assert_equal [12], validator.instance_variable_get(:@codes)
    end

    def test_config_validate_invalid_api_key
      config = good_config
      config[:api_keys][:key1] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [22], validator.instance_variable_get(:@codes)
    end

    def test_confif_validate_no_api_keys
      config = good_config
      config[:api_keys] = nil
      validator = ConfigValidator.new(config: config)
      assert_equal [0], validator.instance_variable_get(:@codes)
    end
  end
end
