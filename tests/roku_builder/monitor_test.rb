# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class MonitorTest < Minitest::Test
  def test_monitor_monit
    connection = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    monitor = RokuBuilder::Monitor.new(**device_config)

    connection.expect(:waitfor, nil) do |config|
      assert_equal(/./, config['Match'])
      assert_equal(false, config['Timeout'])
    end

    def monitor.gets
      sleep(0.1)
      "q"
    end

    Net::Telnet.stub(:new, connection) do
      monitor.monitor(type: :main)
    end

    connection.verify
  end

  def test_monitor_monit_and_manage
    connection = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    monitor = RokuBuilder::Monitor.new(**device_config)

    connection.expect(:waitfor, nil) do |config, &blk|
      assert_equal(/./, config['Match'])
      assert_equal(false, config['Timeout'])
      txt = "Fake Text"
      blk.call(txt) == ""
    end

    def monitor.gets
      sleep(0.1)
      "q"
    end

    Net::Telnet.stub(:new, connection) do
      monitor.stub(:manage_text, "") do
        monitor.monitor(type: :main)
      end
    end

    connection.verify
  end

  def test_monitor_monit_input
    connection = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    monitor = RokuBuilder::Monitor.new(**device_config)

    connection.expect(:waitfor, nil) do |config|
      assert_equal(/./, config['Match'])
      assert_equal(false, config['Timeout'])
    end
    connection.expect(:puts, nil, ["text"])

    def monitor.gets
      @count ||= 0
      sleep(0.1)
      case @count
      when 0
        @count += 1
        "text"
      else
        "q"
      end
    end

    Net::Telnet.stub(:new, connection) do
      monitor.monitor(type: :main)
    end

    connection.verify
  end

  def test_monitor_manage_text
    mock = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    monitor = RokuBuilder::Monitor.new(**device_config)
    monitor.instance_variable_set(:@mock, mock)

    def monitor.puts(input)
      @mock.puts(input)
    end
    def monitor.print(input)
      @mock.print(input)
    end

    mock.expect(:puts, nil, ["midline split\n"])
    mock.expect(:print, nil, ["BrightScript Debugger> "])

    all_text = "midline "
    txt = "split\nBrightScript Debugger> "

    result = monitor.send(:manage_text, {all_text: all_text, txt: txt})

    assert_equal "", result

  end
end
