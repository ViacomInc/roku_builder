# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class LinkerTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.setup_plugins
      register_plugins(Linker)
      @requests = []
    end
    def teardown
      @requests.each {|req| remove_request_stub(req)}
    end
    def test_linker_parse_options_long
      parser = OptionParser.new
      options = {}
      Linker.parse_options(parser: parser, options: options)
      argv = ["roku", "--deeplink", "options", "--app-list", "--app", "app"]
      parser.parse! argv
      assert_equal "options", options[:deeplink]
      assert options[:applist]
      assert_equal "app", options[:app_id]
    end
    def test_linker_parse_options_short
      parser = OptionParser.new
      options = {}
      Linker.parse_options(parser: parser, options: options)
      argv = ["roku", "-o", "options", "-A", "-a", "app"]
      parser.parse! argv
      assert_equal "options", options[:deeplink]
      assert options[:applist]
      assert_equal "app", options[:app_id]
    end
    def test_linker_link
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/launch/dev?a=A&b=B:C&d=a%5Cb").
        to_return(status: 200, body: "", headers: {}))

      options = {deeplink: 'a:A, b:B:C, d:a\b'}
      config, options = build_config_options_objects(LinkerTest, options, false)

      linker = Linker.new(config: config)
      linker.deeplink(options: options)
    end
    def test_linker_link_sideload
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/launch/dev?a=A&b=B:C&d=a%5Cb").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Home").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_install").
        to_return(status: 200, body: "Install Success", headers: {}))

      options = {deeplink: 'a:A, b:B:C, d:a\b',  working: true}
      config, options = build_config_options_objects(LinkerTest, options, false)

      linker = Linker.new(config: config)
      linker.deeplink(options: options)
    end
    def test_linker_link_sideload_current
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/launch/dev?a=A&b=B:C&d=a%5Cb").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/keypress/Home").
        to_return(status: 200, body: "", headers: {}))
      @requests.push(stub_request(:post, "http://192.168.0.100/plugin_install").
        to_return(status: 200, body: "Install Success", headers: {}))

      options = {deeplink: 'a:A, b:B:C, d:a\b',  current: true}
      config = nil
      Pathname.stub(:pwd, test_files_path(LinkerTest)) do
        config, options = build_config_options_objects(LinkerTest, options, false)
      end

      linker = Linker.new(config: config)
      linker.deeplink(options: options)
    end
    def test_linker_link_app
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/launch/1234?a=A&b=B:C&d=a%5Cb").
        to_return(status: 200, body: "", headers: {}))

      options = {deeplink: 'a:A, b:B:C, d:a\b', app_id: "1234"}
      config, options = build_config_options_objects(LinkerTest, options, false)

      linker = Linker.new(config: config)
      linker.deeplink(options: options)
    end
    def test_linker_link_nothing
      @requests.push(stub_request(:post, "http://192.168.0.100:8060/launch/dev").
        to_return(status: 200, body: "", headers: {}))

      options = {deeplink: ''}
      config, options = build_config_options_objects(LinkerTest, options, false)

      linker = Linker.new(config: config)
      linker.deeplink(options: options)
    end

    def test_linker_list
      body = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<apps>\n\t
      <app id=\"31012\" type=\"menu\" version=\"1.6.3\">Movie Store and TV Store</app>\n\t
      <app id=\"31863\" type=\"menu\" version=\"1.2.6\">Roku Home News</app>\n\t
      <app id=\"65066\" type=\"appl\" version=\"1.3.0\">Nick</app>\n\t
      <app id=\"68161\" type=\"appl\" version=\"1.3.0\">Nick</app>\n\t
      </apps>\n"
      @requests.push(stub_request(:get, "http://192.168.0.100:8060/query/apps").
        to_return(status: 200, body: body, headers: {}))

      options = {applist: true}
      config, options = build_config_options_objects(LinkerTest, options, false)

      linker = Linker.new(config: config)

      print_count = 0
      did_print = Proc.new { |msg| print_count+=1 }

      linker.stub(:printf, did_print) do
        linker.applist(options: options)
      end

      assert_equal 6, print_count
    end
  end
end
