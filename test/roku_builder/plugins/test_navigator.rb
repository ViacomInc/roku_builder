# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class NavigatorTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Navigator)
      @requests = []
    end
    def teardown
      @requests.each {|req| remove_request_stub(req)}
    end
    def test_navigator_parse_options_long
      parser = OptionParser.new
      options = {}
      Navigator.parse_options(parser: parser, options: options)
      argv = ["roku", "--nav", "nav", "--navigate", "--type", "text", "--screen",
        "screen", "--screens"]
      parser.parse! argv
      assert_equal "nav", options[:nav]
      assert options[:navigate]
      assert_equal "text", options[:type]
      assert_equal "screen", options[:screen]
      assert options[:screens]
    end
    def test_navigator_parse_options_short
      parser = OptionParser.new
      options = {}
      Navigator.parse_options(parser: parser, options: options)
      argv = ["roku", "-N", "nav", "-y", "text"]
      parser.parse! argv
      assert_equal "nav", options[:nav]
      assert_equal "text", options[:type]
    end
    def test_navigator_nav
      commands = {
        up: "Up",
        down: "Down",
        right: "Right",
        left: "Left",
        select: "Select",
        back: "Back",
        home: "Home",
        rew: "Rev",
        ff: "Fwd",
        play: "Play",
        replay: "InstantReplay"
      }
      commands.each {|k,v|
        path = "/keypress/#{v}"
        navigator_test(path: path, input: k, type: :nav)
      }
    end

    def test_navigator_nav_fail
      path = ""
      navigator_test(path: path, input: :bad, type: :nav, success: false)
    end

    def test_navigator_type
      path = "keypress/LIT_"
      navigator_test(path: path, input: "Type", type: :type)
    end

    def navigator_test(path:, input:, type:, success: true)
      if success
        if type == :nav
          @requests.push(stub_request(:post, "http://192.168.0.100:8060#{path}").
            to_return(status: 200, body: "", headers: {}))
        elsif type == :type
          input.split(//).each do |c|
            path = "/keypress/LIT_#{CGI::escape(c)}"
            @requests.push(stub_request(:post, "http://192.168.0.100:8060#{path}").
              to_return(status: 200, body: "", headers: {}))
          end
        end
      end
      options = {}
      options[type] = input.to_s
      config, options = build_config_options_objects(NavigatorTest, options, false)

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: true}])
      device_manager.expect(:release_device, nil, [device])

      navigator = Navigator.new(config: config)
      RokuBuilder.stub(:device_manager, device_manager) do
        if success
          navigator.send(type, options: options)
        else
          assert_raises ExecutionError do
            navigator.send(type, options: options)
          end
        end
      end
      device_manager.verify
    end

    def test_navigator_screen_secret
      logger = Minitest::Mock.new
      Logger.class_variable_set(:@@instance, logger)
      options = {screen: "secret"}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)

      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Home").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Fwd").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Rev").
        to_return(status: 200, body: "", headers: {}))

      5.times do
        logger.expect(:debug, nil, ["Send Command: /keypress/Home"])
      end
      3.times do
        logger.expect(:debug, nil, ["Send Command: /keypress/Fwd"])
      end
      2.times do
        logger.expect(:debug, nil, ["Send Command: /keypress/Rev"])
      end

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: true}])
      device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, device_manager) do
        navigator.screen(options: options)
      end

      device_manager.verify
      logger.verify
      Logger.set_testing
    end
    def test_navigator_screen_reboot
      logger = Minitest::Mock.new
      command_logger = Minitest::Mock.new
      Logger.class_variable_set(:@@instance, logger)
      options = {screen: "reboot"}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)

      logger.expect(:unknown, nil, ["Cannot run command automatically"])
      command_logger.expect(:unknown, nil, ["Home x 5, Up, Rev x 2, Fwd x 2,"])
      command_logger.expect(:formatter=, nil, [Proc])

      ::Logger.stub(:new, command_logger) do
        navigator.screen(options: options)
      end

      logger.verify
      Logger.set_testing
    end

    def test_navigator_screen_fail
      options = {screen: "bad"}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)
      assert_raises ExecutionError do
        navigator.screen(options: options)
      end
    end

    def test_navigator_screens
      logger = Minitest::Mock.new
      Logger.class_variable_set(:@@instance, logger)
      options = {screens: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)

      logger.expect(:formatter=, nil, [Proc])
      logger.expect(:unknown, nil) do |msg|
        /-+/=~ msg
      end
      navigator.instance_variable_get("@screens").each_key do |key|
        logger.expect(:unknown, nil) do |msg|
          /#{key}:/=~ msg
        end
        logger.expect(:unknown, nil) do |msg|
          /-+/=~ msg
        end
      end

      ::Logger.stub(:new, logger) do
        navigator.screens(options: options)
      end

      logger.verify
      Logger.set_testing
    end

    def test_navigator_read_char
      getc = Minitest::Mock.new
      chr = Minitest::Mock.new

      getc.expect(:call, chr)
      chr.expect(:chr, "a")

      options = {navigate: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)

      navigator = Navigator.new(config: config)
      STDIN.stub(:echo=, nil) do
        STDIN.stub(:raw!, nil) do
          STDIN.stub(:getc, getc) do
            assert_equal "a", navigator.send(:read_char)
          end
        end
      end
      getc.verify
      chr.verify
    end

    def test_navigator_read_char_multichar
      getc = Minitest::Mock.new
      chr = Minitest::Mock.new
      read_nonblock = Minitest::Mock.new

      getc.expect(:call, chr)
      chr.expect(:chr, "\e")
      read_nonblock.expect(:call, "a", [3])
      read_nonblock.expect(:call, "b", [2])

      options = {navigate: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)

      navigator = Navigator.new(config: config)
      STDIN.stub(:echo=, nil) do
        STDIN.stub(:raw!, nil) do
          STDIN.stub(:getc, getc) do
            STDIN.stub(:read_nonblock, read_nonblock) do
              assert_equal "\eab", navigator.send(:read_char)
            end
          end
        end
      end
      getc.verify
      chr.verify
    end

    def test_navigator_interactive
      options = {navigate: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: true}])
      device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, device_manager) do
        navigator.stub(:read_char, "\u0003") do
          navigator.navigate(options: options)
        end
      end
      device_manager.verify
    end

    def test_navigator_interactive_nav
      read_char = lambda {
        @i ||= 0
        char = nil
        case(@i)
        when 0
          char = "<"
        when 1
          char = "\u0003"
        end
        @i += 1
        char
      }
      thread_new = lambda { |char,device|
        assert_equal "<", char
      }
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Rev").
        to_return(status: 200, body: "", headers: {}))
      options = {navigate: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: true}])
      device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, device_manager) do
        navigator.stub(:read_char, read_char) do
          Thread.stub(:new, thread_new, "<") do
            navigator.navigate(options: options)
          end
        end
      end
      device_manager.verify
    end
    def test_navigator_handle_interactive_text
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/LIT_b").
        to_return(status: 200, body: "", headers: {}))
      options = {navigate: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])

      navigator.send(:handle_navigate_input, "b", device)
    end
    def test_navigator_hendle_interactive_command
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Play").
        to_return(status: 200, body: "", headers: {}))
      options = {navigate: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)

      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])

      navigator.send(:handle_navigate_input, "=", device)
    end
    def test_navigator_generate_mappings
      options = {navigate: true}
      config, options = build_config_options_objects(NavigatorTest, options, false)
      navigator = Navigator.new(config: config)
      assert_equal ["home", "Home"], navigator.instance_variable_get(:@mappings)[:a]
    end
  end
end
