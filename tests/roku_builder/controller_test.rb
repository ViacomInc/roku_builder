# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class ControllerTest < Minitest::Test
  def test_controller_validate_options
    options = {
      sideload: true,
      package: true
    }
    assert_equal RokuBuilder::EXTRA_COMMANDS, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {}
    assert_equal RokuBuilder::NO_COMMANDS,  RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      sideload: true,
      working: true,
      current: true
    }
    assert_equal RokuBuilder::EXTRA_SOURCES, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      sideload: true,
      working: true
    }
    assert_equal RokuBuilder::VALID, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      package: true
    }
    assert_equal RokuBuilder::NO_SOURCE, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      package: true,
      current: true
    }
    assert_equal RokuBuilder::BAD_CURRENT, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      package: true,
      in: true
    }
    assert_equal RokuBuilder::BAD_IN_FILE, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      deeplink: "a:b c:d",
      deeplink_depricated: true
    }
    assert_equal RokuBuilder::DEPRICATED, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      sideload: true,
      current: true
    }
    assert_equal RokuBuilder::VALID, RokuBuilder::Controller.send(:validate_options, {options: options})
    options = {
      package: true,
      in: "",
      set_stage: true
    }
    assert_equal RokuBuilder::EXTRA_SOURCES, RokuBuilder::Controller.send(:validate_options, {options: options})
  end
  def test_controller_configure
    logger = Logger.new("/dev/null")
    target_config = File.join(File.dirname(__FILE__), "test_files", "controller_test", "configure_test.json")
    File.delete(target_config) if File.exist?(target_config)
    assert !File.exist?(target_config)

    options = {
      configure: true,
      config: target_config,
    }

    code = RokuBuilder::Controller.send(:configure, {options: options, logger: logger})

    assert File.exist?(target_config)

    options = {
      configure: true,
      config: target_config,
      edit_params: "ip:111.222.333.444"
    }

    code = RokuBuilder::Controller.send(:configure, {options: options, logger: logger})

    assert File.exist?(target_config)
    config = RokuBuilder::ConfigManager.get_config(config: target_config, logger: logger)
    assert_equal "111.222.333.444", config[:devices][config[:devices][:default]][:ip]

    options = {
      configure: true,
      config: target_config
    }

    code = RokuBuilder::Controller.send(:configure, {options: options, logger: logger})

    assert_equal RokuBuilder::CONFIG_OVERWRITE, code

    File.delete(target_config) if File.exist?(target_config)
  end

  def test_controller_check_devices
    logger = Logger.new("/dev/null")
    ping = Minitest::Mock.new
    options = {device_given: false}
    config = {}
    config[:devices] = {
      a: {ip: "2.2.2.2"},
      b: {ip: "3.3.3.3"}
    }
    configs = {
      device_config: {ip: "1.1.1.1"}
    }

    Net::Ping::External.stub(:new, ping) do

      ping.expect(:ping?, true, [configs[:device_config][:ip], 1, 0.2, 1])
      code, ret = RokuBuilder::Controller.send(:check_devices, {options: options, config: config, configs: configs, logger: logger})
      assert_equal RokuBuilder::GOOD_DEVICE, code

      ping.expect(:ping?, false, [configs[:device_config][:ip], 1, 0.2, 1])
      ping.expect(:ping?, false, [config[:devices][:a][:ip], 1, 0.2, 1])
      ping.expect(:ping?, false, [config[:devices][:b][:ip], 1, 0.2, 1])
      code, ret = RokuBuilder::Controller.send(:check_devices, {options: options, config: config, configs: configs, logger: logger})
      assert_equal RokuBuilder::NO_DEVICES, code

      ping.expect(:ping?, false, [configs[:device_config][:ip], 1, 0.2, 1])
      ping.expect(:ping?, true, [config[:devices][:a][:ip], 1, 0.2, 1])
      code, ret = RokuBuilder::Controller.send(:check_devices, {options: options, config: config, configs: configs, logger: logger})
      assert_equal RokuBuilder::CHANGED_DEVICE, code
      assert_equal config[:devices][:a][:ip], ret[:device_config][:ip]

      options[:device_given] = true
      ping.expect(:ping?, false, [configs[:device_config][:ip], 1, 0.2, 1])
      code, ret = RokuBuilder::Controller.send(:check_devices, {options: options, config: config, configs: configs, logger: logger})
      assert_equal RokuBuilder::BAD_DEVICE, code
    end
  end

  def test_controller_run_debug
    tests = [
      {options: {debug: true}, level: Logger::DEBUG},
      {options: {verbose: true}, level: Logger::INFO},
      {options: {}, level: Logger::WARN}
    ]
    tests.each do |test|
      logger = Minitest::Mock.new
      logger.expect(:formatter=, nil) do |proc_object|
        proc_object.class == Proc and proc_object.arity == 4
      end
      logger.expect(:level=, nil, [test[:level]])
      Logger.stub(:new, logger) do
        RokuBuilder::Controller.stub(:validate_options, nil) do
          RokuBuilder::ErrorHandler.stub(:handle_options_codes, nil) do
            RokuBuilder::Controller.stub(:configure, nil) do
              RokuBuilder::ErrorHandler.stub(:handle_configure_codes, nil) do
                RokuBuilder::ConfigManager.stub(:load_config, nil) do
                  RokuBuilder::ErrorHandler.stub(:handle_load_codes, nil) do
                    RokuBuilder::Controller.stub(:check_devices, nil) do
                      RokuBuilder::ErrorHandler.stub(:handle_device_codes, nil) do
                        RokuBuilder::Controller.stub(:execute_commands, nil) do
                          RokuBuilder::ErrorHandler.stub(:handle_command_codes, nil) do
                            RokuBuilder::Controller.run(options: test[:options])
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      logger.verify
    end
  end
end

