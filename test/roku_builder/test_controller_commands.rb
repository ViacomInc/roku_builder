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

    options = RokuBuilder::Options.new(options: {sideload: true, config: "~/.roku_config.rb", working: true})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    # Test Success
    loader.expect(:sideload, [RokuBuilder::SUCCESS, "build_version"], [config.parsed[:sideload_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    code = nil
    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::Stager.stub(:new, stager) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code

    stager.expect(:stage, true)
    stager.expect(:unstage, true)

    # Test Failure
    loader.expect(:sideload, [RokuBuilder::FAILED_SIDELOAD, "build_version"], [config.parsed[:sideload_config]])
    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::Stager.stub(:new, stager) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
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

    options = RokuBuilder::Options.new(options: {package: true, inspect: true, out_folder: "/tmp", config: "~/.roku_config.json", set_stage: true})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    info = {app_name: "app", dev_id: "id", creation_date: "date", dev_zip: ""}

    loader.expect(:sideload, [RokuBuilder::SUCCESS, "build_version"], [config.parsed[:sideload_config]])
    keyer.expect(:rekey, true, [config.parsed[:key]])
    packager.expect(:package, true, [config.parsed[:package_config]])
    inspector.expect(:inspect, info, [config.parsed[:inspect_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    code = nil
    RokuBuilder::Keyer.stub(:new, keyer) do
      RokuBuilder::Loader.stub(:new, loader) do
        RokuBuilder::Packager.stub(:new, packager) do
          RokuBuilder::Inspector.stub(:new, inspector) do
            RokuBuilder::Stager.stub(:new, stager) do
              Logger.stub(:new, logger) do
                code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
              end
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

    options = RokuBuilder::Options.new(options: {package: true, inspect: true, out: "/tmp/out.pkg", config: "~/.roku_config.json", set_stage: true})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    info = {app_name: "app", dev_id: "id", creation_date: "date", dev_zip: ""}

    loader.expect(:sideload, [RokuBuilder::SUCCESS, "build_version"], [config.parsed[:sideload_config]])
    keyer.expect(:rekey, true, [config.parsed[:key]])
    packager.expect(:package, true, [config.parsed[:package_config]])
    inspector.expect(:inspect, info, [config.parsed[:inspect_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    code = nil
    RokuBuilder::Keyer.stub(:new, keyer) do
      RokuBuilder::Loader.stub(:new, loader) do
        RokuBuilder::Packager.stub(:new, packager) do
          RokuBuilder::Inspector.stub(:new, inspector) do
            RokuBuilder::Stager.stub(:new, stager) do
              Logger.stub(:new, logger) do
                code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
              end
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
    options = RokuBuilder::Options.new(options: {build: true, out_folder: "/tmp", config: "~/.roku_config.json", working: true})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    loader.expect(:build, "/tmp/build", [config.parsed[:build_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    stager.expect(:method, :git)

    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::ManifestManager.stub(:build_version, "1") do
        RokuBuilder::Stager.stub(:new, stager) do
          code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
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
    options = RokuBuilder::Options.new(options: {update: true, out_folder: "/tmp", config: "~/.roku_config.json", working: true})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    mock.expect(:call, "1", [config.parsed[:manifest_config]])
    mock.expect(:call, "2", [config.parsed[:manifest_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)

    RokuBuilder::ManifestManager.stub(:build_version, mock) do
      RokuBuilder::ManifestManager.stub(:update_build, mock) do
        RokuBuilder::Stager.stub(:new, stager) do
          code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
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
    options = RokuBuilder::Options.new(options: {deeplink: true, deeplink_options: "a:b", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    mock.expect(:launch, "true", [config.parsed[:deeplink_config]])
    RokuBuilder::Linker.stub(:new, mock) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
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
    options = RokuBuilder::Options.new(options: {deeplink: true, set_stage: true, deeplink_options: "a:b", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    mock.expect(:launch, "true", [config.parsed[:deeplink_config]])
    RokuBuilder::Linker.stub(:new, mock) do
      RokuBuilder::ControllerCommands.stub(:sideload, sideload) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
      end
    end
    mock.verify
    assert_equal RokuBuilder::SUCCESS, code
    assert ran_sideload
  end
  def test_controller_commands_deeplink_fail
    logger = Logger.new("/dev/null")
    mock = Minitest::Mock.new
    stager = Minitest::Mock.new

    code = nil
    options = RokuBuilder::Options.new(options: {deeplink: true, deeplink_options: "a:b", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    mock.expect(:launch, false, [config.parsed[:deeplink_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    RokuBuilder::Linker.stub(:new, mock) do
      RokuBuilder::Stager.stub(:new, stager) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
      end
    end
    mock.verify
    assert_equal RokuBuilder::FAILED_DEEPLINKING, code
  end
  def test_controller_commands_delete
    logger = Logger.new("/dev/null")
    loader = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {delete: true, config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    loader.expect(:unload, nil)
    code = nil
    RokuBuilder::Loader.stub(:new, loader) do
      RokuBuilder::ManifestManager.stub(:build_version, "1") do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    loader.verify
  end
  def test_controller_commands_monitor
    logger = Logger.new("/dev/null")
    monitor = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {monitor: "main", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    monitor.expect(:monitor, nil, [config.parsed[:monitor_config]])
    code = nil
    RokuBuilder::Monitor.stub(:new, monitor) do
      RokuBuilder::ManifestManager.stub(:build_version, "1") do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    monitor.verify
  end
  def test_controller_commands_navigate
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {navigate: "up", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    navigator.expect(:nav, true, [config.parsed[:navigate_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_navigate_fail
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {navigate: "up", config: ":execute_commands,/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    navigator.expect(:nav, nil, [config.parsed[:navigate_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal RokuBuilder::FAILED_NAVIGATING, code
    navigator.verify
  end
  def test_controller_commands_screen
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {screen: "secret", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    navigator.expect(:screen, true, [config.parsed[:screen_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_screens
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {screens: true, config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    navigator.expect(:screens, true)
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_text
    logger = Logger.new("/dev/null")
    navigator = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {text: "text string", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    navigator.expect(:type, true, [config.parsed[:text_config]])
    code = nil
    RokuBuilder::Navigator.stub(:new, navigator) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    navigator.verify
  end
  def test_controller_commands_test
    logger = Logger.new("/dev/null")
    tester = Minitest::Mock.new
    stager = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {test: true, config: "~/.roku_config.json", working: true})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    tester.expect(:run_tests, true, [config.parsed[:test_config]])
    stager.expect(:stage, true)
    stager.expect(:unstage, true)
    code = nil

    RokuBuilder::Stager.stub(:new, stager) do
      RokuBuilder::Tester.stub(:new, tester) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    tester.verify
    stager.verify
  end
  def test_controller_commands_screencapture
    logger = Logger.new("/dev/null")
    inspector = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {screencapture: true, out: "/tmp/capture.jpg", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    inspector.expect(:screencapture, true, [config.parsed[:screencapture_config]])
    code = nil
    RokuBuilder::Inspector.stub(:new, inspector) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal RokuBuilder::SUCCESS, code
    inspector.verify
  end
  def test_controller_commands_screencapture_fail
    logger = Logger.new("/dev/null")
    inspector = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {screencapture: true, out: "/tmp", config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@config, good_config)
    config.parse
    inspector.expect(:screencapture, false, [config.parsed[:screencapture_config]])
    code = nil
    RokuBuilder::Inspector.stub(:new, inspector) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal RokuBuilder::FAILED_SCREENCAPTURE, code
    inspector.verify
  end
  def test_controller_commands_print
    logger = Logger.new("/dev/null")
    stager = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {print: 'title', config: "~/.roku_config.json", working: true})
    configs = {stage_config: {}}
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@parsed, configs)
    code = nil
    scripter_config = {attribute: :title, configs: configs}
    print_check = lambda {|print_config| RokuBuilder::SUCCESS if print_config == scripter_config }
    stager.expect(:stage, true)
    stager.expect(:unstage, true)

    RokuBuilder::Stager.stub(:new, stager) do
      RokuBuilder::Scripter.stub(:print, print_check) do
        code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
      end
    end
    assert_equal RokuBuilder::SUCCESS, code
    stager.verify
  end
  def test_controller_commands_dostage
    logger = Logger.new("/dev/null")
    stager = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {dostage: true, config: "~/.roku_config.json"})
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@parsed, {stage_config: {}})
    code = nil
    stager.expect(:stage, true)

    RokuBuilder::Stager.stub(:new, stager) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal true, code
    stager.verify
  end

  def test_controller_commands_dounstage
    logger = Logger.new("/dev/null")
    stager = Minitest::Mock.new

    options = RokuBuilder::Options.new(options: {dounstage: true, config: "~/.roku_config.json"})
    configs = {stage_config: {}}
    config = RokuBuilder::Config.new(options: options)
    config.instance_variable_set(:@parsed, configs)
    code = nil
    stager.expect(:unstage, true)

    RokuBuilder::Stager.stub(:new, stager) do
      code = RokuBuilder::Controller.send(:execute_commands, {options: options, config: config, logger: logger})
    end
    assert_equal true, code
    stager.verify
  end
end
