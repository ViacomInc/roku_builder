# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class ControllerCommandsTest < Minitest::Test

  def test_controller_commands_validate
    logger = Minitest::Mock.new
    logger.expect(:info, nil, ["Config validated"])
    code = RokuBuilder::ControllerCommands.validate(logger: logger)
    assert_equal RokuBuilder::SUCCESS, code
    logger.verify
  end
  def test_controller_commands_sideload
    logger = Logger.new("/dev/null")
    loader = Minitest::Mock.new
    stager = Minitest::Mock.new

    options = {sideload: true, stage: 'production', config: "~/.roku_config.rb"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    # Test Success
    loader.expect(:sideload, [RokuBuilder::SUCCESS, "build_version"], [configs[:sideload_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::Stager.stub(:new, stager) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code

    stager.expect(:stage, true)
    stager.expect(:unstage, true)

    # Test Failure
    loader.expect(:sideload, [RokuBuilder::FAILED_SIDELOAD, "build_version"], [configs[:sideload_config]])
    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::Stager.stub(:new, stager) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
      end
    end
    assert_equal RokuBuilder::FAILED_SIDELOAD, code

    loader.verify
    stager.verify
  end

  def test_controller_commands_package
    logger = Logger.new("/dev/null")
    keyer = Minitest::Mock.new
    loader = Minitest::Mock.new
    stager = Minitest::Mock.new
    packager = Minitest::Mock.new
    inspector = Minitest::Mock.new

    options = {package: true, inspect: true, stage: 'production', out_folder: "/tmp", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    info = {app_name: "app", dev_id: "id", creation_date: "date", dev_zip: ""}

    loader.expect(:sideload, [RokuBuilder::SUCCESS, "build_version"], [configs[:sideload_config]])
    keyer.expect(:rekey, true, [configs[:key]])
    packager.expect(:package, true, [configs[:package_config]])
    inspector.expect(:inspect, info, [configs[:inspect_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    code = nil
    RokuBuilder::Keyer.stub(:new, keyer) do
      RokuBuilder::Loader.stub(:new, loader) do
        RokuBuilder::Packager.stub(:new, packager) do
          RokuBuilder::Inspector.stub(:new, inspector) do
            RokuBuilder::Stager.stub(:new, stager) do
              code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
            end
          end
        end
      end
    end
    assert_equal RokuBuilder::SUCCESS, code

    keyer.verify
    loader.verify
    stager.verify
    packager.verify
    inspector.verify
  end

  def test_controller_commands_package_outfile
    logger = Logger.new("/dev/null")
    keyer = Minitest::Mock.new
    loader = Minitest::Mock.new
    stager = Minitest::Mock.new
    packager = Minitest::Mock.new
    inspector = Minitest::Mock.new

    options = {package: true, inspect: true, stage: 'production', out: "/tmp/out.pkg", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    info = {app_name: "app", dev_id: "id", creation_date: "date", dev_zip: ""}

    loader.expect(:sideload, [RokuBuilder::SUCCESS, "build_version"], [configs[:sideload_config]])
    keyer.expect(:rekey, true, [configs[:key]])
    packager.expect(:package, true, [configs[:package_config]])
    inspector.expect(:inspect, info, [configs[:inspect_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    code = nil
    RokuBuilder::Keyer.stub(:new, keyer) do
      RokuBuilder::Loader.stub(:new, loader) do
        RokuBuilder::Packager.stub(:new, packager) do
          RokuBuilder::Inspector.stub(:new, inspector) do
            RokuBuilder::Stager.stub(:new, stager) do
              code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
            end
          end
        end
      end
    end
    assert_equal RokuBuilder::SUCCESS, code

    keyer.verify
    loader.verify
    stager.verify
    packager.verify
    inspector.verify
  end

  def test_controller_commands_build
    logger = Logger.new("/dev/null")
    loader = Minitest::Mock.new
    stager = Minitest::Mock.new

    code = nil
    options = {build: true, stage: 'production', out_folder: "/tmp", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    loader.expect(:build, "/tmp/build", [configs[:build_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::ManifestManager.stub(:build_version, "1") do
        RokuBuilder::Stager.stub(:new, stager) do
          code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
        end
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    loader.verify
    stager.verify
  end
  def test_controller_commands_update
    logger = Logger.new("/dev/null")
    mock = Minitest::Mock.new
    stager = Minitest::Mock.new

    code = nil
    options = {update: true, stage: 'production', out_folder: "/tmp", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    mock.expect(:call, "1", [configs[:manifest_config]])
    mock.expect(:call, "2", [configs[:manifest_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)

    RokuBuilder::ManifestManager.stub(:build_version, mock) do
      RokuBuilder::ManifestManager.stub(:update_build, mock) do
        RokuBuilder::Stager.stub(:new, stager) do
          code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
        end
      end
    end
    mock.verify
    stager.verify
    assert_equal RokuBuilder::SUCCESS, code
  end

  def test_controller_commands_deeplink
    logger = Logger.new("/dev/null")
    mock = Minitest::Mock.new

    code = nil
    options = {deeplink: true, stage: 'production', deeplink_options: "a:b", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    mock.expect(:launch, "true", [configs[:deeplink_config]])
    RokuBuilder::Linker.stub(:new, mock) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    mock.verify
    assert_equal RokuBuilder::SUCCESS, code
  end
  def test_controller_commands_deeplink_sideload
    logger = Logger.new("/dev/null")
    mock = Minitest::Mock.new

    ran_sideload = false

    sideload =  Proc.new {|a, b, c| ran_sideload = true}

    code = nil
    options = {deeplink: true, set_stage: true, stage: 'production', deeplink_options: "a:b", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    mock.expect(:launch, "true", [configs[:deeplink_config]])
    RokuBuilder::Linker.stub(:new, mock) do
      RokuBuilder::ControllerCommands.stub(:sideload, sideload) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
      end
    end
    mock.verify
    assert_equal RokuBuilder::SUCCESS, code
    assert ran_sideload
  end
  def test_controller_commands_deeplink_fail
    logger = Logger.new("/dev/null")
    mock = Minitest::Mock.new

    code = nil
    options = {deeplink: true, stage: 'production', deeplink_options: "a:b", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    mock.expect(:launch, false, [configs[:deeplink_config]])
    RokuBuilder::Linker.stub(:new, mock) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    mock.verify
    assert_equal RokuBuilder::FAILED_DEEPLINKING, code
  end
  def test_controller_commands_delete
    logger = Logger.new("/dev/null")
    loader = Minitest::Mock.new

    options = {delete: true, stage: 'production', config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    loader.expect(:unload, nil)
    code = nil
    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::ManifestManager.stub(:build_version, "1") do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    loader.verify
  end
  def test_controller_commands_monitor
    logger = Logger.new("/dev/null")
    monitor = Minitest::Mock.new

    options = {monitor: "main", stage: 'production', config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    monitor.expect(:monitor, nil, [configs[:monitor_config]])
    code = nil
    RokuBuilder::Monitor.stub(:new, monitor) do
      RokuBuilder::ManifestManager.stub(:build_version, "1") do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    monitor.verify
  end
  def test_controller_commands_navigate
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = {navigate: "up", stage: 'production', config: ":execute_commands,/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    navigator.expect(:nav, true, [configs[:navigate_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_navigate_fail
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = {navigate: "up", stage: 'production', config: ":execute_commands,/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    navigator.expect(:nav, nil, [configs[:navigate_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::FAILED_NAVIGATING, code
    navigator.verify
  end
  def test_controller_commands_screen
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = {screen: "secret", stage: 'production', config: ":execute_commands,/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    navigator.expect(:screen, true, [configs[:screen_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_screens
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = {screens: true, stage: 'production', config: ":execute_commands,/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    navigator.expect(:screens, true)
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_text
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = {text: "text string", stage: 'production', config: ":execute_commands,/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    navigator.expect(:type, true, [configs[:text_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_test
    logger = Logger.new("/dev/null")
    tester = Minitest::Mock.new

    options = {test: true, stage: 'production', config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    tester.expect(:run_tests, true, [configs[:test_config]])
    code = nil
    RokuBuilder::Tester.stub(:new, tester) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    tester.verify
  end
  def test_controller_commands_screencapture
    logger = Logger.new("/dev/null")
    inspector = Minitest::Mock.new

    options = {screencapture: true, stage: 'production', out: "/tmp/capture.jpg", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    inspector.expect(:screencapture, true, [configs[:screencapture_config]])
    code = nil
    RokuBuilder::Inspector.stub(:new, inspector) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    inspector.verify
  end
  def test_controller_commands_screencapture_fail
    logger = Logger.new("/dev/null")
    inspector = Minitest::Mock.new

    options = {screencapture: true, stage: 'production', out: "/tmp", config: "~/.roku_config.json"}
    config = good_config
    code, configs = RokuBuilder::ConfigParser.parse_config(options: options, config: config, logger: logger)
    inspector.expect(:screencapture, false, [configs[:screencapture_config]])
    code = nil
    RokuBuilder::Inspector.stub(:new, inspector) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, configs: configs, logger: logger})
    end
    assert_equal RokuBuilder::FAILED_SCREENCAPTURE, code
    inspector.verify
  end
end
