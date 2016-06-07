# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class ConfigValidatorTest < Minitest::Test

  def test_config_manager_validate_devices
    config = good_config
    config[:devices] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [1], codes
  end

  def test_config_manager_validate_devices_default
    config = good_config
    config[:devices][:default] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [2], codes
  end

  def test_config_manager_validate_devices_default_is_symbol
    config = good_config
    config[:devices][:default] = "bad"
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [3], codes
  end

  def test_config_manager_validate_device_ip
    config = good_config
    config[:devices][:roku][:ip] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [7], codes
  end

  def test_config_manager_validate_device_ip_empty
    config = good_config
    config[:devices][:roku][:ip] = ""
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [7], codes
  end

  def test_config_manager_validate_device_ip_default_value
    config = good_config
    config[:devices][:roku][:ip] = "xxx.xxx.xxx.xxx"
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [7], codes
  end

  def test_config_manager_validate_device_user
    config = good_config
    config[:devices][:roku][:user] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [8], codes
  end

  def test_config_manager_validate_device_user_empty
    config = good_config
    config[:devices][:roku][:user] = ""
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [8], codes
  end

  def test_config_manager_validate_device_user_default_value
    config = good_config
    config[:devices][:roku][:user] = "<username>"
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [8], codes
  end

  def test_config_manager_validate_device_password
    config = good_config
    config[:devices][:roku][:password] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [9], codes
  end

  def test_config_manager_validate_device_password_empty
    config = good_config
    config[:devices][:roku][:password] = ""
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [9], codes
  end

  def test_config_manager_validate_device_password_default_value
    config = good_config
    config[:devices][:roku][:password] = "<password>"
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [9], codes
  end

  def test_config_manager_validate_projects
    config = good_config
    config[:projects] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [4], codes
  end

  def test_config_manager_validate_projects_default
    config = good_config
    config[:projects][:default] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [5], codes
  end

  def test_config_manager_validate_projects_default_default_value
    config = good_config
    config[:projects][:default] = "<project id>".to_sym
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [5], codes
  end

  def test_config_manager_validate_projects_default_is_symbol
    config = good_config
    config[:projects][:default] = "project_id"
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [6], codes
  end

  def test_config_manager_validate_project_app_name
    config = good_config
    config[:projects][:project1][:app_name] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [10], codes
  end

  def test_config_manager_validate_project_directory
    config = good_config
    config[:projects][:project1][:directory] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [11], codes
  end

  def test_config_manager_validate_project_folders
    config = good_config
    config[:projects][:project1][:folders] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [12], codes
  end

  def test_config_manager_validate_project_folders_is_array
    config = good_config
    config[:projects][:project1][:folders] = "Folders"
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [13], codes
  end

  def test_config_manager_validate_project_files
    config = good_config
    config[:projects][:project1][:files] = nil
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [14], codes
  end

  def test_config_manager_validate_project_filess_is_array
    config = good_config
    config[:projects][:project1][:files] = "Files"
    codes = RokuBuilder::ConfigValidator.validate_config(config: config)
    assert_equal [15], codes
  end
end
