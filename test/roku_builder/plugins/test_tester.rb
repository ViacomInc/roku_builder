# ********** Copyright Viacom, Inc. Apache 2.0 **********
require_relative "../test_helper.rb"

module RokuBuilder
  class TesterTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Tester)
      @connection = Minitest::Mock.new
      @requests = []

      @device_manager = Minitest::Mock.new

      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Home").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_install").
        to_return(status: 200, body: "Install Success", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/launch/dev?RunTests=true").
        to_return(status: 200, body: "", headers: {}))
    end
    def teardown
      @device_manager.verify
      @connection.verify
      @requests.each {|req| remove_request_stub(req)}
    end
    def test_scripter_parse_options_long
      parser = OptionParser.new
      options = {}
      Tester.parse_options(parser: parser, options: options)
      argv = ["roku", "--test"]
      parser.parse! argv
      assert options[:test]
    end
    def test_tester_runtests
      config, options = build_config_options_objects(TesterTest, {test: true, working: true}, false)
      tester = Tester.new(config: config)

      @connection.expect(:waitfor, nil, [/\*+\s*End testing\s*\*+/])
      @connection.expect(:puts, nil, ["cont\n"])

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, [{no_lock: false}])
      @device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, @device_manager) do
        Net::Telnet.stub(:new, @connection) do
          tester.test(options: options)
        end
      end
    end

    def test_tester_runtests_and_handle
      config, options = build_config_options_objects(TesterTest, {test: true, working: true}, false)
      tester = Tester.new(config: config)

      waitfor = Proc.new do |end_reg, &blk|
        assert_equal(/\*+\s*End testing\s*\*+/, end_reg)
        txt = "Fake Text"
        blk.call(txt) == false
      end

      @connection.expect(:waitfor, nil, &waitfor)
      @connection.expect(:puts, nil, ["cont\n"])

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      @device_manager.expect(:reserve_device, device, [{no_lock: false}])
      @device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, @device_manager) do
        Net::Telnet.stub(:new, @connection) do
          tester.stub(:handle_text, false) do
            tester.test(options: options)
          end
        end
      end
    end

    def test_tester_handle_text_no_text
      config = build_config_options_objects(TesterTest, {test: true, working: true}, false)[0]
      tester = Tester.new(config: config)

      text = "this\nis\na\ntest\nparagraph"
      tester.send(:handle_text, txt: text)

      refute tester.instance_variable_get(:@in_tests)
    end

    def test_tester_handle_text_all_text
      config = build_config_options_objects(TesterTest, {test: true, working: true}, false)[0]
      tester = Tester.new(config: config)
      tester.instance_variable_set(:@in_tests, true)

      text = ["this","is","a","test","paragraph"]

      tester.send(:handle_text, txt: text.join("\n"))
      assert_equal text, tester.instance_variable_get(:@logs)
      assert tester.instance_variable_get(:@in_tests)
    end

    def test_tester_handle_text_partial_text
      config = build_config_options_objects(TesterTest, {test: true, working: true}, false)[0]
      tester = Tester.new(config: config)

      text = ["this","*Start testing*","is","a","test","*End testing*","paragraph"]
      verify_text = ["***************","***************","*Start testing*","is","a","test","*End testing*","*************","*************"]

      tester.send(:handle_text, txt: text.join("\n"))
      refute tester.instance_variable_get(:@in_tests)
      assert_equal verify_text, tester.instance_variable_get(:@logs)
    end

    def test_tester_handle_text_used_connection
      config = build_config_options_objects(TesterTest, {test: true, working: true}, false)[0]
      tester = Tester.new(config: config)

      text = ["connection already in use"]

      assert_raises IOError do
        tester.send(:handle_text, txt: text.join("\n"))
      end
    end
  end
end
