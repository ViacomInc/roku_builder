# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class ProfilerTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      unless RokuBuilder.plugins.include?(Profiler)
        RokuBuilder.register_plugin(Profiler)
      end
    end
    def test_profiler_parse_options_long
      parser = OptionParser.new
      options = {}
      Profiler.parse_options(parser: parser, options: options)
      argv = ["roku", "--profile", "command", "--sgperf", "--devlog", "on"]
      parser.parse! argv
      assert_equal "command", options[:profile]
    end
    def test_profiler_node_tracking
      options = {profile: "stats"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = "<All_Nodes><NodeA /><NodeB /><NodeC><NodeD /></NodeC></All_Nodes>\n"
        blk.call(txt)
        true
      end
      count = 0
      read_stub = Proc.new do |size|
        shouldExit = (count = 2)
        raise SystemExit if shouldExit
        count += 1
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, ["sgnodes all\n"])
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:printf, nil) do
          STDIN.stub(:read, read_stub) do
            profiler.node_tracking(options: options)
          end
        end
      end

      connection.verify
    end
    def test_profiler_stats
      options = {profile: "stats"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = "<All_Nodes><NodeA /><NodeB /><NodeC><NodeD /></NodeC></All_Nodes>\n"
        blk.call(txt)
        true
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, ["sgnodes all\n"])
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:printf, nil) do
          profiler.profile(options: options)
        end
      end

      connection.verify
    end
    def test_profiler_all
      options = {profile: "all"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = "<All_Nodes><NodeA /><NodeB /><NodeC><NodeD /></NodeC></All_Nodes>\n"
        blk.call(txt)
        true
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, ["sgnodes all\n"])
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:print, nil) do
          profiler.profile(options: options)
        end
      end

      connection.verify
    end
    def test_profiler_roots
      options = {profile: "roots"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = "<Root_Nodes><NodeA /><NodeB /><NodeC><NodeD /></NodeC></Root_Nodes>\n"
        blk.call(txt)
        true
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, ["sgnodes roots\n"])
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:print, nil) do
          profiler.profile(options: options)
        end
      end
      connection.verify
    end
    def test_profiler_node
      options = {profile: "nodeId"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = "<nodeId><NodeA /><NodeB /><NodeC><NodeD /></NodeC></nodeId>\n"
        blk.call(txt)
        true
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, ["sgnodes nodeId\n"])
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:print, nil) do
          profiler.profile(options: options)
        end
      end
      connection.verify
    end
    def test_profiler_images
      options = {profile: "images"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = " RoGraphics instance\n0x234 1 2 3 4\nAvailable memory\n"
        blk.call(txt)
        true
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, ["r2d2_bitmaps\n"])
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:print, nil) do
          profiler.profile(options: options)
        end
      end

      connection.verify
    end

    def test_profiler_memmory
      options = {profile: "memmory"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = " RoGraphics instance 0x123\nAvailable memory 123 used 456 max 579\n"
        blk.call(txt)
        true
      end
      print_count = 0
      print_stub = Proc.new do |message|
        case print_count
        when 0
          assert_equal "\r", message
        when 1
          assert_equal "0x123: 78%\n", message
        end
        print_count +=1
        true
      end
      first = true
      puts_stub = Proc.new do |message|
        if first
          assert_equal "r2d2_bitmaps\n", message
          first  = false
        else
          raise SystemExit
        end
        true
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, &puts_stub)
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:puts, nil, &puts_stub)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:print, print_stub) do
          profiler.profile(options: options)
        end
      end

      assert print_count > 1
      connection.verify
    end
    def test_profiler_textures
      options = {profile: "textures"}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      waitfor = Proc.new do |telnet_config, &blk|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        txt = "*******\ntexture\n"
        blk.call(txt)
        true
      end
      timeout = Proc.new do |telnet_config, &blk|
        raise ::Net::ReadTimeout
      end
      connection = Minitest::Mock.new
      profiler = Profiler.new(config: config)

      connection.expect(:puts, nil, ["loaded_textures\n"])
      connection.expect(:waitfor, nil, &waitfor)
      connection.expect(:waitfor, nil, &timeout)
      connection.expect(:close, nil)

      Net::Telnet.stub(:new, connection) do
        profiler.stub(:print, nil) do
          profiler.profile(options: options)
        end
      end

      connection.verify
    end
    def test_profiler_devlog
      options = {devlog: "rendezvous", devlog_function: "on"}
      config, options = build_config_options_objects(ProfilerTest, options, false)

      connection = Minitest::Mock.new
      connection.expect(:puts, nil, ["enhanced_dev_log rendezvous on\n"])

      profiler = Profiler.new(config: config)
      Net::Telnet.stub(:new, connection) do
        profiler.devlog(options: options)
      end
      connection.verify
    end
    def test_profiler_sgperf
      options = {sgperf: true}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      profiler = Profiler.new(config: config)

      connection = Object.new
      connection.define_singleton_method(:puts){}
      connection.define_singleton_method(:waitfor){}
      connection.define_singleton_method(:close){}

      message_count = {}
      puts_stub = Proc.new { |message|
        message_count[message] ||= 0
        message_count[message] += 1
        case message
        when "sgperf clear\n"
          assert_equal 1, message_count[message]
        when "sgperf start\n"
          assert_equal 1, message_count[message]
        when "sgperf report\n"
          if message_count[message] > 1
            raise SystemExit
          end
        end
      }
      waitfor = Proc.new {|telnet_config|
        assert_equal(/.+/, telnet_config["Match"])
        assert_equal(1, telnet_config["Timeout"])
        raise Net::ReadTimeout
      }

      Net::Telnet.stub(:new, connection) do
        connection.stub(:puts, puts_stub) do
          txt = ">>thread node calls: create     0 + op    24  @ 100.0% rendezvous"
          connection.stub(:waitfor, waitfor, txt) do
            profiler.sgperf(options: options)
          end
        end
      end

      assert(0 < message_count["sgperf clear\n"])
      assert(0 < message_count["sgperf start\n"])
      assert(0 < message_count["sgperf report\n"])

    end
    def test_profiler_sgperf_multi_lines
      options = {sgperf: true}
      config, options = build_config_options_objects(ProfilerTest, options, false)
      profiler = Profiler.new(config: config)

      connection = Object.new
      connection.define_singleton_method(:puts){}
      connection.define_singleton_method(:waitfor){}
      connection.define_singleton_method(:close){}

      message_count = {}
      connection_puts = Proc.new { |message|
        message_count[message] ||= 0
        message_count[message] += 1
        case message
        when "sgperf clear\n"
          assert_equal 1, message_count[message]
        when "sgperf start\n"
          assert_equal 1, message_count[message]
        end
      }
      first = true
      command_response = Proc.new {
        if first
          first = false
          [">>thread node calls: create     0 + op    24  @ 0.0% rendezvous",
            "thread node calls: create     1 + op    0  @ 100.0% rendezvous",
            "thread node calls: create     0 + op    1  @ 100.0% rendezvous"]
        else
          raise SystemExit
        end
      }
      call_count = 0
      profiler_puts = Proc.new { |message|
        case call_count
        when 0
          assert_equal("Thread 0: c:0 u:24 r:0.0%", message)
        when 1
          assert_equal("Thread 1: c:1 u:0 r:100.0%", message)
        when 2
          assert_equal("Thread 2: c:0 u:1 r:100.0%", message)
        end
        call_count += 1
      }

      Net::Telnet.stub(:new, connection) do
        connection.stub(:puts, connection_puts) do
          profiler.stub(:get_command_response, command_response) do
            profiler.stub(:puts, profiler_puts) do
              profiler.sgperf(options: options)
            end
          end
        end
      end

      assert(2 < call_count)
      assert(0 < message_count["sgperf clear\n"])
      assert(0 < message_count["sgperf start\n"])

    end
  end
end
