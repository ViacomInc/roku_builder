# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"
module RokuBuilder
  class InspectorTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Inspector)
      @requests = []
    end
    def teardown
      @requests.each {|req| remove_request_stub(req)}
    end
    def test_inspector_parse_options_long
      parser = OptionParser.new
      options = {}
      Inspector.parse_options(parser: parser, options: options)
      argv = ["roku", "--inspect", "--screencapture", "--password", "password"]
      parser.parse! argv
      assert options[:inspect]
      assert options[:screencapture]
      assert_equal "password", options[:password]
    end
    def test_scripter_parse_options_short
      parser = OptionParser.new
      options = {}
      Inspector.parse_options(parser: parser, options: options)
      argv = ["roku", "-S"]
      parser.parse! argv
      assert options[:screencapture]
    end
    def test_inspector_inspect

      logger = Minitest::Mock.new()

      logger.expect(:formatter=, nil, [Proc])
      logger.expect(:unknown, nil){|text| /=*/ =~ text}
      logger.expect(:unknown, nil){|text| /app_name/ =~ text}
      logger.expect(:unknown, nil){|text| /dev_id/ =~ text}
      logger.expect(:unknown, nil, [String])
      logger.expect(:unknown, nil){|text| /dev_zip/ =~ text}
      logger.expect(:unknown, nil){|text| /=*/ =~ text}

      body = "r1.insertCell(0).innerHTML = 'App Name: ';"+
        "      r1.insertCell(1).innerHTML = '<div class=\"roku-color-c3\">app_name</div>';"+
        ""+
        "      var r2 = table.insertRow(1);"+
        "      r2.insertCell(0).innerHTML = 'Dev ID: ';"+
        "      r2.insertCell(1).innerHTML = '<div class=\"roku-color-c3\"><font face=\"Courier\">dev_id</font></div>';"+
        "      "+
        "      var dd = new Date(628232400);"+
        "      var ddStr = \"\";"+
        "      ddStr += (dd.getMonth()+1);"+
        "      ddStr += \"/\";"+
        "      ddStr += dd.getDate();"+
        "      ddStr += \"/\";"+
        "      ddStr += dd.getFullYear();"+
        "      ddStr += \" \";"+
        "      ddStr += dd.getHours();"+
        "      ddStr += \":\";"+
        "      ddStr += dd.getMinutes();"+
        "      ddStr += \":\";"+
        "      ddStr += dd.getSeconds(); "+
        "      "+
        "      var r3 = table.insertRow(2);"+
        "      r3.insertCell(0).innerHTML = 'Creation Date: ';"+
        "      r3.insertCell(1).innerHTML = '<div class=\"roku-color-c3\">'+ddStr+'</div>';"+
        "      "+
        "      var r4 = table.insertRow(3);"+
        "      r4.insertCell(0).innerHTML = 'dev.zip: ';"+
        "      r4.insertCell(1).innerHTML = '<div class=\"roku-color-c3\"><font face=\"Courier\">dev_zip</font></div>';"

      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: body, headers: {}))

      options = {inspect: true, in: File.join(test_files_path(InspectorTest), "test.pkg"), password: "password"}
      config, options = build_config_options_objects(InspectorTest, options, false)
      inspector = Inspector.new(config: config)

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: false}])
      device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, device_manager) do
        ::Logger.stub(:new, logger) do
          inspector.inspect(options: options)
        end
      end
      logger.verify
      device_manager.verify
    end
    def test_inspector_inspect_old_interface
      logger = Minitest::Mock.new()

      logger.expect(:formatter=, nil, [Proc])
      logger.expect(:unknown, nil){|text| /=*/ =~ text}
      logger.expect(:unknown, nil){|text| /app_name/ =~ text}
      logger.expect(:unknown, nil){|text| /dev_id/ =~ text}
      logger.expect(:unknown, nil, [String])
      logger.expect(:unknown, nil){|text| /dev_zip/ =~ text}
      logger.expect(:unknown, nil){|text| /=*/ =~ text}
      body = " <table cellpadding=\"2\">"+
        " <tbody><tr><td> App Name: </td><td> <font color=\"blue\">app_name</font> </td></tr>"+
        " <tr><td> Dev ID: </td><td> <font face=\"Courier\" color=\"blue\">dev_id</font> </td></tr>"+
        " <tr><td> Creation Date: </td><td> <font color=\"blue\">"+
        " <script type=\"text/javascript\">"+
        " var d = new Date(628232400)"+
        " document.write(d.getMonth()+1)"+
        " document.write(\"/\")"+
        " document.write(d.getDate())"+
        " document.write(\"/\");"+
        " document.write(d.getFullYear())"+
        " document.write(\" \")"+
        " document.write(d.getHours())"+
        " document.write(\":\")"+
        " document.write(d.getMinutes())"+
        " document.write(\":\")"+
        " document.write(d.getSeconds())"+
        " </script>1/17/1970 16:42:28"+
        " </font> </td></tr>"+
        " <tr><td> dev.zip: </td><td> <font face=\"Courier\" color=\"blue\">dev_zip</font> </td></tr>"+
        " </tbody></table>"

      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: body, headers: {}))

      options = {inspect: true, in: File.join(test_files_path(InspectorTest), "test.pkg"), password: "password"}
      config, options = build_config_options_objects(InspectorTest, options, false)
      inspector = Inspector.new(config: config)

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: false}])
      device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, device_manager) do
        ::Logger.stub(:new, logger) do
          inspector.inspect(options: options)
        end
      end

      logger.verify
      device_manager.verify
    end

    def test_screencapture
      body = "<hr /><img src=\"pkgs/dev.jpg?time=1455629573\">"
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: body, headers: {}))

      body2 = "<screencapture>"
      @requests.push(stub_request(:get, "http://192.168.0.100/pkgs/dev.jpg?time=1455629573").
        to_return(status: 200, body: body2, headers: {}))

      io = Minitest::Mock.new()
      io.expect("write", nil, [body2])

      options = {screencapture: true }
      config, options = build_config_options_objects(InspectorTest, options, false)
      inspector = Inspector.new(config: config)

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: false}])
      device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, device_manager) do
        File.stub(:open, nil, io) do
          inspector.screencapture(options: options)
        end
      end
      io.verify
      device_manager.verify
    end
    def test_screencapture_png
      body = "<hr /><img src=\"pkgs/dev.png?time=1455629573\">"
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_inspect").
        to_return(status: 200, body: body, headers: {}))

      body2 = "<screencapture>"
      @requests.push(stub_request(:get, "http://192.168.0.100/pkgs/dev.png?time=1455629573").
        to_return(status: 200, body: body2, headers: {}))

      io = Minitest::Mock.new()
      io.expect("write", nil, [body2])

      options = {screencapture: true }
      config, options = build_config_options_objects(InspectorTest, options, false)
      inspector = Inspector.new(config: config)

      device_manager = Minitest::Mock.new
      device = RokuBuilder::Device.new("roku", config.raw[:devices][:roku])
      device_manager.expect(:reserve_device, device, [{no_lock: false}])
      device_manager.expect(:release_device, nil, [device])

      RokuBuilder.stub(:device_manager, device_manager) do
        File.stub(:open, nil, io) do
          inspector.screencapture(options: options)
        end
      end
    end
  end
end
