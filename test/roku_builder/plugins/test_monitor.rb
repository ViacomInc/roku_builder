# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class MonitorTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      unless RokuBuilder.plugins.include?(Monitor)
        RokuBuilder.register_plugin(Monitor)
      end
      @options = build_options({monitor: "main"}, false)
      @config = Config.new(options: @options)
      @connection = Object.new()
      @connection.define_singleton_method(:waitfor) {}
      @connection.define_singleton_method(:puts) {}
      device_config = {
        ip: "111.222.333",
        user: "user",
        password: "password"
      }
      @monitor = Monitor.new(config: @config)
      @device_manager = Minitest::Mock.new
      @device = RokuBuilder::Device.new("roku", device_config)
    end
    def teardown
      @device_manager.verify
    end
    def test_scripter_parse_options_long
      parser = OptionParser.new
      options = {}
      Monitor.parse_options(parser: parser, options: options)
      argv = ["roku", "--monitor", "--regexp", "regexp"]
      parser.parse! argv
      assert options[:monitor]
      assert_equal "regexp", options[:regexp]
    end
    def test_scripter_parse_options_short
      parser = OptionParser.new
      options = {}
      Monitor.parse_options(parser: parser, options: options)
      argv = ["roku", "-m", "-r", "regexp"]
      parser.parse! argv
      assert options[:monitor]
      assert_equal "regexp", options[:regexp]
    end
    def test_monitor_monit
      count = 0
      waitfor = proc {
        count += 1
      }
      readline = proc {
        sleep(0.1)
        "q"
      }
      @device_manager.expect(:reserve_device, @device, no_lock: true)
      @device_manager.expect(:release_device, nil, [@device])

      RokuBuilder.stub(:device_manager, @device_manager) do
        Readline.stub(:readline, readline) do
          Net::Telnet.stub(:new, @connection) do
            @connection.stub(:waitfor, waitfor, "txt") do
              @monitor.monitor(options: @options)
            end
          end
        end
      end

      assert count > 0
    end

    def test_monitor_monit_and_manage
      @monitor.instance_variable_set(:@show_prompt, true)
      count = 0
      waitfor = proc {
        count += 1
      }
      readline = proc {
        sleep(0.1)
        "q"
      }
      @device_manager.expect(:reserve_device, @device, no_lock: true)
      @device_manager.expect(:release_device, nil, [@device])

      RokuBuilder.stub(:device_manager, @device_manager) do
        Readline.stub(:readline, readline) do
          Net::Telnet.stub(:new, @connection) do
            @connection.stub(:waitfor, waitfor, "txt") do
              @monitor.stub(:manage_text, "") do
                @monitor.monitor(options: @options)
              end
            end
          end
        end
      end
      assert count > 0
    end

    def test_monitor_monit_input
      @monitor.instance_variable_set(:@show_prompt, true)
      wait_count = 0
      waitfor = proc {
        wait_count += 1
      }

      puts_count = 0
      puts = proc { |text|
        puts_count += 1
        assert_equal("text", text)
        @monitor.instance_variable_set(:@show_prompt, true)
      }

      readline = proc {
        @count ||= 0
        sleep(0.1)
        case @count
        when 0
          @count += 1
          "text"
        else
          "q"
        end
      }
      @device_manager.expect(:reserve_device, @device, no_lock: true)
      @device_manager.expect(:release_device, nil, [@device])

      RokuBuilder.stub(:device_manager, @device_manager) do
        Readline.stub(:readline, readline) do
          Net::Telnet.stub(:new, @connection) do
            @connection.stub(:waitfor, waitfor, "txt") do
              @connection.stub(:puts, puts) do
                @monitor.monitor(options: @options)
              end
            end
          end
        end
      end
      assert wait_count > 0
      assert puts_count > 0
    end

    def test_monitor_manage_text
      mock = Minitest::Mock.new
      @monitor.instance_variable_set(:@show_prompt, true)
      @monitor.instance_variable_set(:@mock, mock)

      def @monitor.puts(input)
        @mock.puts(input)
      end

      mock.expect(:puts, nil, ["midline split\n"])

      all_text = "midline "
      txt = "split\nBrightScript Debugger> "

      result = @monitor.send(:manage_text, all_text: all_text, txt: txt)

      assert_equal "", result

      mock.verify

    end

    def test_monitor_manage_text_connection_used
      assert_raises ExecutionError do
        @monitor.send(:manage_text, all_text: "", txt: "Console connection is already in use.")
      end
    end
  end
end
