# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class ConfigParserTest < Minitest::Test
  def test_manifest_config
    logger = Logger.new("/dev/null")
    options = {
      config: File.expand_path(File.join(File.dirname(__FILE__), "test_files", "controller_config_test", "valid_config.json")),
      stage: 'production',
      update_manifest: false,
      fetch: false,
    }
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)

    assert_equal RokuBuilder::SUCCESS, code
    assert_equal Hash, config.class
    assert_equal "/dev/null", configs[:manifest_config][:root_dir]
  end

  def test_setup_project_config_current
    args = {
      config: {},
      options: {current: true }
    }
    project = {}
    File.stub(:exist?, true) do
      project = RokuBuilder::ConfigParser.send(:setup_project_config, **args)
    end
    assert_equal Pathname.pwd.to_s, project[:directory]
    assert_equal :current, project[:stage_method]
    assert_nil project[:folders]
    assert_nil project[:files]
  end

  def test_setup_stage_config_script
    args = {
      configs: {project_config: {directory: "/tmp", stage_method: :script, stages: {production: {script: "script"}}}},
      options: {stage: "production"},
      logger: Logger.new("/dev/null")
    }
    config, stage = RokuBuilder::ConfigParser.send(:setup_stage_config, **args)
    assert_equal args[:configs][:project_config][:stages][:production][:script], config[:key]
  end

  def test_setup_stage_config_git_ref
    args = {
      configs: {project_config: {directory: "/tmp", stage_method: :git, }},
      options: {stage: "production", ref: "git-ref"},
      logger: Logger.new("/dev/null")
    }
    config, stage = RokuBuilder::ConfigParser.send(:setup_stage_config, **args)
    assert_equal args[:options][:ref], config[:key]
  end

  def test_manifest_config_project_select
    logger = Logger.new("/dev/null")
    options = {
      config: File.expand_path(File.join(File.dirname(__FILE__), "test_files", "controller_config_test", "valid_config.json")),
      stage: 'production',
      update_manifest: false,
      fetch: false,
    }
    config = good_config

    code = nil
    configs = nil

    Pathname.stub(:pwd, Pathname.new("/dev/nuller")) do
      code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    end

    assert_equal RokuBuilder::SUCCESS, code
    assert_equal Hash, config.class
    assert_equal "/dev/nuller", configs[:project_config][:directory]
  end

  def test_setup_sideload_config
    args = {
      configs: {project_config: {directory: "/tmp", folders: ["a", "b"], files: ["c", "d"], excludes: []}, init_params: {}},
      options: {sideload: true}
    }
    RokuBuilder::ConfigParser.send(:setup_sideload_config, **args)

    refute_nil args[:configs][:sideload_config]
    refute_nil args[:configs][:sideload_config][:content]
    refute_nil args[:configs][:build_config]
    refute_nil args[:configs][:build_config][:content]
    refute_nil args[:configs][:init_params][:loader]
    refute_nil args[:configs][:init_params][:loader][:root_dir]

    assert_nil args[:configs][:sideload_config][:content][:excludes]
    assert_nil args[:configs][:sideload_config][:update_manifest]
    assert_nil args[:configs][:sideload_config][:infile]
  end
  def test_setup_sideload_config_exclude
    args = {
      configs: {project_config: {directory: "/tmp", folders: ["a", "b"], files: ["c", "d"], excludes: []}, init_params: {}},
      options: {sideload: true}
    }
    RokuBuilder::ConfigParser.send(:setup_sideload_config, **args)
    assert_nil args[:configs][:sideload_config][:content][:excludes]

    args = {
      configs: {project_config: {directory: "/tmp", folders: ["a", "b"], files: ["c", "d"], excludes: []}, init_params: {}},
      options: {build: true}
    }
    RokuBuilder::ConfigParser.send(:setup_sideload_config, **args)
    refute_nil args[:configs][:sideload_config][:content][:excludes]

    args = {
      configs: {project_config: {directory: "/tmp", folders: ["a", "b"], files: ["c", "d"], excludes: []}, init_params: {}},
      options: {package: true}
    }
    RokuBuilder::ConfigParser.send(:setup_sideload_config, **args)
    refute_nil args[:configs][:sideload_config][:content][:excludes]

    args = {
      configs: {project_config: {directory: "/tmp", folders: ["a", "b"], files: ["c", "d"], excludes: []}, init_params: {}},
      options: {sideload: true, exclude: true}
    }
    RokuBuilder::ConfigParser.send(:setup_sideload_config, **args)
    refute_nil args[:configs][:sideload_config][:content][:excludes]
  end
end
