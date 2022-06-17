# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class PackagerTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Packager)
      @requests = []
      @device_manager = Minitest::Mock.new
    end
    def teardown
      @requests.each {|req| remove_request_stub(req)}
      @device_manager.verify
      clean_device_locks()
    end
    def test_packager_parse_options_long
      parser = OptionParser.new
      options = {}
      Packager.parse_options(parser: parser, options: options)
      argv = ["roku", "--package", "--key", "--genkey", "--inspect-package"]
      parser.parse! argv
      assert options[:package]
      assert options[:key]
      assert options[:genkey]
      assert options[:inspect_package]
    end
    def test_scripter_parse_options_short
      parser = OptionParser.new
      options = {}
      Packager.parse_options(parser: parser, options: options)
      argv = ["roku", "-p", "-k", "-i"]
      parser.parse! argv
      assert options[:package]
      assert options[:key]
      assert options[:inspect_package]
    end
    def test_packager_current
      config, options = [nil, nil]
      Pathname.stub(:pwd, test_files_path(PackagerTest)) do
        config, options = build_config_options_objects(PackagerTest, {package: true, current: true}, false)
      end
      packager = Packager.new(config: config)
      assert_raises InvalidOptions do
        packager.package(options: options)
      end
    end
    def test_packager_in
      config, options = build_config_options_objects(PackagerTest, {package: true, in: "/tmp/test.pkg"}, false)
      packager = Packager.new(config: config)
      assert_raises InvalidOptions do
        packager.package(options: options)
      end
    end
    def test_packager_ref
      config, options = build_config_options_objects(PackagerTest, {package: true, ref: "test_ref"}, false)
      packager = Packager.new(config: config)
      assert_raises InvalidOptions do
        packager.package(options: options)
      end
    end
    def test_packager_package_failed
      config, options = build_config_options_objects(PackagerTest, {package: true, stage: "production"}, false)
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Home").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_install").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_package").
        to_return(status: 200, body: "Failed: Error.", headers: {}))
      packager = Packager.new(config: config)
      RokuBuilder.stub(:device_manager, @device_manager) do
        assert_raises ExecutionError do
          packager.package(options: options)
        end
      end
    end
    def test_packager_package
      loader = Minitest::Mock.new
      inspector = Minitest::Mock.new
      io = Minitest::Mock.new
      logger = Minitest::Mock.new
      config, options = build_config_options_objects(PackagerTest, {package: true, stage: "production", inspect_package: true, verbose: true}, false)

      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: "", headers: {}).times(2))
      body = "<a href=\"pkgs\">pkg_url</a>"
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_package").
        to_return(status: 200, body: body, headers: {}).times(2))
      body = "package_body"
      @requests.push(stub_request(:get, "http://192.168.0.100/pkgs/pkg_url").
        to_return(status: 200, body: body, headers: {}))

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      loader.expect(:sideload, nil, options: Hash, device: device)
      io.expect(:write, nil, ["package_body"])
      inspector.expect(:inspect, nil, options: Hash, device: device)

      logger.expect(:debug, nil, [String])
      io.expect(:each_line, nil)
      logger.expect(:warn, nil) do |message|
        assert_match(/#{tmp_folder}/, message)
      end

      Logger.class_variable_set(:@@instance, logger)
      packager = Packager.new(config: config)
      dev_id = Proc.new {"#{Random.rand(999999999999)}"}
      RokuBuilder.stub(:device_manager, @device_manager) do
        Loader.stub(:new, loader) do
          Time.stub(:now, Time.at(0)) do
            File.stub(:open, nil, io) do
              Inspector.stub(:new, inspector) do
                packager.stub(:dev_id, dev_id) do
                  packager.package(options: options)
                end
              end
            end
          end
        end
      end
      io.verify
      loader.verify
      inspector.verify
      logger.verify
    end
    def test_packager_package_squash
      loader = Minitest::Mock.new
      inspector = Minitest::Mock.new
      io = Minitest::Mock.new
      logger = Minitest::Mock.new
      config = good_config(PackagerTest)
      config[:projects][:project1][:stages][:production][:squash] = true
      config, options = build_config_options_objects(PackagerTest, {package: true, stage: "production", inspect_package: true, verbose: true}, false, config)

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: "", headers: {}).times(2))
      body = "<a href=\"pkgs\">pkg_url</a>"
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_package").
        to_return(status: 200, body: body, headers: {}).times(2))
      body = "package_body"
      @requests.push(stub_request(:get, "http://192.168.0.100/pkgs/pkg_url").
        to_return(status: 200, body: body, headers: {}))

      loader.expect(:sideload, nil, options: Hash, device: device)
      loader.expect(:squash, nil, options: Hash, device: device)
      io.expect(:write, nil, ["package_body"])
      inspector.expect(:inspect, nil, options: Hash, device: device)

      logger.expect(:debug, nil, [String])
      io.expect(:each_line, nil)
      logger.expect(:warn, nil) do |message|
        assert_match(/#{tmp_folder}/, message)
      end

      Logger.class_variable_set(:@@instance, logger)
      packager = Packager.new(config: config)
      dev_id = Proc.new {"#{Random.rand(999999999999)}"}
      RokuBuilder.stub(:device_manager, @device_manager) do
        Loader.stub(:new, loader) do
          Time.stub(:now, Time.at(0)) do
            File.stub(:open, nil, io) do
              Inspector.stub(:new, inspector) do
                packager.stub(:dev_id, dev_id) do
                  packager.package(options: options)
                end
              end
            end
          end
        end
      end
      io.verify
      loader.verify
      inspector.verify
      logger.verify
    end
    def test_packager_dev_id
      body = "v class=\"roku-font-5\"><label>Your Dev ID: &nbsp;</label> dev_id<hr></div>"
      @requests.push(stub_request(:get, "http://192.168.0.100/plugin_package").
        to_return(status: 200, body: body, headers: {}))

      config = build_config_options_objects(PackagerTest, {key: true, stage: "production"}, false)[0]

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      packager = Packager.new(config: config)
      dev_id = nil
      RokuBuilder.stub(:device_manager, @device_manager) do
        dev_id = packager.dev_id
      end

      assert_equal "dev_id", dev_id
    end
    def test_packager_dev_id_old_interface
      body = "<p> Your Dev ID: <font face=\"Courier\">dev_id</font> </p>"
      @requests.push(stub_request(:get, "http://192.168.0.100/plugin_package").
        to_return(status: 200, body: body, headers: {}))

      config = build_config_options_objects(PackagerTest, {key: true, stage: "production"}, false)[0]
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      packager = Packager.new(config: config)
      dev_id = nil
      RokuBuilder.stub(:device_manager, @device_manager) do
        dev_id = packager.dev_id
      end

      assert_equal "dev_id", dev_id
    end

    def test_packager_key_changed
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: "", headers: {}))
      logger = Minitest::Mock.new
      logger.expect(:debug, nil) {|s| s =~ /\d* -> \d*/}
      dev_id = Proc.new {"#{Random.rand(999999999999)}"}
      config, options = build_config_options_objects(PackagerTest, {key: true, stage: "production"}, false)
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      packager = Packager.new(config: config)
      Logger.class_variable_set(:@@instance, logger)
      RokuBuilder.stub(:device_manager, @device_manager) do
        packager.stub(:dev_id, dev_id) do
          packager.key(options: options)
        end
      end
    end

    def test_packager_key_same
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: "", headers: {}))
      logger = Minitest::Mock.new
      logger.expect(:info, nil) {|s| s =~ /did not change/}
      logger.expect(:debug, nil) {|s| s =~ /\d* -> \d*/}
      dev_id = Proc.new {"#{Random.rand(999999999999)}"}
      config, options = build_config_options_objects(PackagerTest, {key: true, stage: "production"}, false)
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      packager = Packager.new(config: config)
      Logger.class_variable_set(:@@instance, logger)
      RokuBuilder.stub(:device_manager, @device_manager) do
        packager.stub(:dev_id, dev_id) do
          packager.key(options: options)
        end
      end
    end

    def test_packager_key_same_device
      config, options = build_config_options_objects(PackagerTest, {key: true, stage: "production"}, false)
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      body = "<p> Your Dev ID: <font face=\"Courier\">dev_id</font> </p>"
      @requests.push(stub_request(:get, "http://192.168.0.100/plugin_package").
        to_return(status: 200, body: body, headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: "", headers: {}))
      packager = Packager.new(config: config)
      RokuBuilder.stub(:device_manager, @device_manager) do
        packager.key(options: options)
      end
    end

    def test_packager_generate_new_key
      connection = Minitest::Mock.new()
      connection.expect(:puts, nil, ["genkey"])
      connection.expect(:waitfor, nil) do |config, &blk|
        assert_equal(/./, config['Match'])
        assert_equal(false, config['Timeout'])
        txt = "Password: password\nDevID: devid\n"
        blk.call(txt)
        true
      end
      connection.expect(:close, nil, [])

      config = build_config_options_objects(PackagerTest, {genkey: true}, false)[0]
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      packager = Packager.new(config: config)
      RokuBuilder.stub(:device_manager, @device_manager) do
        Net::Telnet.stub(:new, connection) do
          packager.send(:generate_new_key)
        end
      end
    end

    def test_packager_no_key
      config = good_config(PackagerTest)
      config[:projects][:project1][:stages][:production].delete(:key)
      config, options = build_config_options_objects(PackagerTest, {key: true, stage: "production"}, false, config)
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      packager = Packager.new(config: config)
      dev_id = Proc.new {"#{Random.rand(999999999999)}"}
      assert_raises ExecutionError do
        RokuBuilder.stub(:device_manager, @device_manager) do
          packager.stub(:dev_id, dev_id) do
            packager.key(options: options)
          end
        end
      end
    end

    def test_packager_genkey

      body = "<a href=\"pkgs\">pkg_url</a>"
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_package").
         to_return(status: 200, body: body, headers: {}))
      @requests.push(stub_request(:get, "http://192.168.0.100/pkgs/pkg_url").
        to_return(status: 200, body: "", headers: {}))
      config, options = build_config_options_objects(PackagerTest, {genkey: true}, false)

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, no_lock: false)
      @device_manager.expect(:release_device, nil, [device])

      loader = Minitest::Mock.new
      loader.expect(:sideload, nil, options: Hash)

      packager = Packager.new(config: config)
      RokuBuilder.stub(:device_manager, @device_manager) do
        Loader.stub(:new, loader) do
          packager.stub(:generate_new_key, ["password", "dev_id"]) do
            packager.genkey(options: options)
          end
        end
      end
      loader.verify
    end
  end
end
