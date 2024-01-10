# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class DeviceManagerTest < Minitest::Test
    def setup
      Logger.set_testing
      @ping = Minitest::Mock.new
      clean_device_locks(["roku", "test2"])
    end

    def teardown
      @ping.verify
      clean_device_locks(["roku", "test2"])
    end

    def test_device_manager_init
      config, options = build_config_options_objects(DeviceManagerTest)
      manager = DeviceManager.new(config: config, options: options)
      assert_equal config, manager.instance_variable_get(:@config)
      assert_equal options, manager.instance_variable_get(:@options)
    end

    def test_device_manager_reserve_device
      Net::Ping::External.stub(:new, @ping) do
        config, options = build_config_options_objects(DeviceManagerTest)
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        device = manager.reserve_device
        assert_kind_of Device, device
        assert_equal "roku", device.name
      end
    end

    def test_device_manager_reserve_device_default_offline
      Net::Ping::External.stub(:new, @ping) do
        config, options = build_config_options_objects(DeviceManagerTest)
        @ping.expect(:ping?, false, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        assert_raises(DeviceError) do
          manager.reserve_device
        end
      end
    end

    def test_device_manager_reserve_device_all_used
      Net::Ping::External.stub(:new, @ping) do
        config, options = build_config_options_objects(DeviceManagerTest)
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        manager.reserve_device
        assert_raises(DeviceError) do
          manager.reserve_device
        end
      end
    end

    def test_device_manager_reserve_device_no_lock_first
      Net::Ping::External.stub(:new, @ping) do
        config, options = build_config_options_objects(DeviceManagerTest)
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        device1 = manager.reserve_device(no_lock: true)
        device2 = manager.reserve_device
        assert_equal "roku", device1.name
        assert_equal "roku", device2.name
      end
    end

    def test_device_manager_release_device
      Net::Ping::External.stub(:new, @ping) do
        config, options = build_config_options_objects(DeviceManagerTest)
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        device1 = manager.reserve_device
        manager.release_device(device1)
        device2 = manager.reserve_device
        assert_equal "roku", device2.name
      end
    end

    def test_device_manager_reserve_device_2_devices
      Net::Ping::External.stub(:new, @ping) do
        options = {validate: true}
        config = good_config(DeviceManagerTest)
        config[:devices][:test2] = {
          ip: "192.168.0.101",
          user: "user",
          password: "password"
        }
        config, options = build_config_options_objects(DeviceManagerTest, options, true, config)
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, true, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, true, [config.raw[:devices][:test2][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        device1 = manager.reserve_device
        device2 = manager.reserve_device
        assert_equal "roku", device1.name
        assert_equal "test2", device2.name
      end
    end

    def test_device_manager_reserve_device_2_devices_default_missing
      Net::Ping::External.stub(:new, @ping) do
        options = {validate: true}
        config = good_config(DeviceManagerTest)
        config[:devices][:test2] = {
          ip: "192.168.0.101",
          user: "user",
          password: "password"
        }
        config, options = build_config_options_objects(DeviceManagerTest, options, true, config)
        @ping.expect(:ping?, false, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, true, [config.raw[:devices][:test2][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, false, [config.raw[:devices][:roku][:ip], 1, 0.2, 1])
        @ping.expect(:ping?, true, [config.raw[:devices][:test2][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        device1 = manager.reserve_device
        assert_raises(DeviceError) do
          manager.reserve_device
        end
        assert_equal "test2", device1.name
      end
    end

    def test_device_manager_reserve_device_specified
      Net::Ping::External.stub(:new, @ping) do
        options = {validate: true, device: "test2"}
        config = good_config(DeviceManagerTest)
        config[:devices][:test2] = {
          ip: "192.168.0.101",
          user: "user",
          password: "password"
        }
        config, options = build_config_options_objects(DeviceManagerTest, options, true, config)
        @ping.expect(:ping?, true, [config.raw[:devices][:test2][:ip], 1, 0.2, 1])
        manager = DeviceManager.new(config: config, options: options)
        device = manager.reserve_device
        assert_kind_of Device, device
        assert_equal "test2", device.name
      end
    end

    def test_device_manager_reserve_device_blocking
      Net::Ping::External.stub(:new, FakePing.new) do
        Thread.abort_on_exception = true
        options = {validate: true, device_blocking: true}
        config, options = build_config_options_objects(DeviceManagerTest, options)
        manager = DeviceManager.new(config: config, options: options)
        device = manager.reserve_device
        t = Thread.new do
          Thread.current[:device] = manager.reserve_device
        end
        manager.release_device(device)
        t.join
        assert_equal "roku", t[:device].name
      end
    end

    def test_device_manager_reserve_device_blocking_timeout
      Net::Ping::External.stub(:new, FakePing.new) do
        options = {validate: true, device_blocking: true}
        config, options = build_config_options_objects(DeviceManagerTest, options)
        manager = DeviceManager.new(config: config, options: options)
        manager.instance_variable_set(:@timeout_duration, 0.01)
        device = manager.reserve_device
        assert_raises(DeviceError) do
          puts manager.reserve_device.name
          puts device.name
        end
      end
    end
  end
  class FakePing
    def initialize(ret: true)
      @ret = ret
    end
    def ping?(*args)
      @ret
    end
  end
end

