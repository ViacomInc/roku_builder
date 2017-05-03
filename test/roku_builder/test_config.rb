# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class ConfigTest < Minitest::Test

  def test_config_init
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
  end

  def test_config_expand_path
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
    options[:config].sub!(/#{File.expand_path("~")}/, "~")
    config = RokuBuilder::Config.new(options: options)
    config.load
  end

  def test_missing_config
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "missing.json"), validate: true})
    assert_raises ArgumentError do
      config = RokuBuilder::Config.new(options: options)
      config.load
    end
  end

  def test_invalid_config
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "bad.json"), validate: true})
    assert_raises RokuBuilder::InvalidConfig do
      config = RokuBuilder::Config.new(options: options)
      config.load
      config.validate
    end
  end

  def test_non_json_config
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "non_json.json"), validate: true})
    assert_raises RokuBuilder::InvalidConfig do
      config = RokuBuilder::Config.new(options: options)
      config.load
    end
  end

  def test_config_parse
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    config.parse
    assert_equal Hash, config.parsed.class
  end

  def test_config_read
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "config.json"), validate: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    assert_equal :roku, config.raw[:devices][:default]
    assert_equal :p1, config.raw[:projects][:default]
  end

  def test_config_read_parent
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "child.json"), validate: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    assert_equal :roku, config.raw[:devices][:default]
    assert_equal :p1, config.raw[:projects][:default]
  end

  def test_config_read_parent
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "parent_projects.json"), validate: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    assert_equal "app", config.raw[:projects][:p1][:app_name]
  end

  def test_config_edit
    orginal = File.join(test_files_path(ConfigTest), "config.json")
    tmp = File.join(test_files_path(ConfigTest), "tmpconfig.json")
    FileUtils.cp(orginal, tmp)
    options = RokuBuilder::Options.new(options: {config: tmp, edit_params: "ip:123.456.789", validate: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    config.edit
    options = RokuBuilder::Options.new(options: {config: tmp, validate: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    assert_equal "123.456.789", config.raw[:devices][:roku][:ip]
    FileUtils.rm(tmp)
  end

  def test_config_update_package
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "config.json"), package: true, stage: :production, set_stage: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    config.parse
    options[:build_version] = "BUILDVERSION"
    config.update
    assert_equal "app - production - BUILDVERSION", config.parsed[:package_config][:app_name_version]
    assert_equal "/tmp/app_production_BUILDVERSION", config.parsed[:package_config][:out_file]
    assert_equal "/tmp/app_production_BUILDVERSION", config.parsed[:inspect_config][:pkg]
  end

  def test_config_update_build
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "config.json"), build: true, stage: :production, set_stage: true})
    config = RokuBuilder::Config.new(options: options)
    config.load
    config.parse
    options[:build_version] = "BUILDVERSION"
    config.update
    assert_equal "/tmp/app_production_BUILDVERSION", config.parsed[:build_config][:out_file]
  end

  def test_config_update_sideload
    options = RokuBuilder::Options.new(options: {config: File.join(test_files_path(ConfigTest), "config.json"), sideload: true, stage: :production, set_stage: true, out: "/tmp2"})
    config = RokuBuilder::Config.new(options: options)
    config.load
    config.parse
    options[:build_version] = "BUILDVERSION"
    config.update
    assert_equal "/tmp2/app_production_BUILDVERSION", config.parsed[:sideload_config][:out_file]
  end
end
