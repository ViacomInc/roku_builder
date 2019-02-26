# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class LoaderTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Loader)
      @config, @options = build_config_options_objects(LoaderTest, {sideload: true, working: true}, false)
      @root_dir = @config.root_dir
      @device_config = @config.device_config
      FileUtils.cp(File.join(@root_dir, "manifest_template"), File.join(@root_dir, "manifest"))
      @request_stubs = []
    end
    def teardown
      FileUtils.rm(File.join(@root_dir, "manifest"))
      @request_stubs.each {|req| remove_request_stub(req)}
    end
    def test_loader_parse_options_long
      parser = OptionParser.new
      options = {}
      Loader.parse_options(parser: parser, options: options)
      argv = ["roku", "--sideload", "--delete", "--build", "--exclude"]
      parser.parse! argv
      assert options[:sideload]
      assert options[:delete]
      assert options[:build]
      assert options[:exclude]
    end
    def test_loader_parse_options_short
      parser = OptionParser.new
      options = {}
      Loader.parse_options(parser: parser, options: options)
      argv = ["roku", "-l", "--squash", "-d", "-b", "-x"]
      parser.parse! argv
      assert options[:sideload]
      assert options[:squash]
      assert options[:delete]
      assert options[:build]
      assert options[:exclude]
    end
    def test_loader_sideload
      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}:8060/keypress/Home").
        to_return(status: 200, body: "", headers: {}))
      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}/plugin_install").
        to_return(status: 200, body: "Install Success", headers: {}))

      loader = Loader.new(config: @config)
      loader.sideload(options: @options)
    end
    def test_loader_sideload_infile
      infile = File.join(@root_dir, "test.zip")
      @config, @options = build_config_options_objects(LoaderTest, {
        sideload: true,
        in: infile
      }, false)

      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}:8060/keypress/Home").
        to_return(status: 200, body: "", headers: {}))
      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}/plugin_install").
        to_return(status: 200, body: "Install Success", headers: {}))

      loader = Loader.new(config: @config)
      loader.sideload(options: @options)
    end
    def test_loader_build_defining_folder_and_files
      loader = Loader.new(config: @config)
      loader.build(options: @options)
      file_path = File.join(@config.out[:folder], Manifest.new(config: @config).build_version+".zip")
      Zip::File.open(file_path) do |file|
        assert file.find_entry("manifest") != nil
        assert_nil file.find_entry("a")
        assert file.find_entry("source/b") != nil
        assert file.find_entry("source/c/d") != nil
      end
      FileUtils.rm(file_path)
    end
    def test_loader_build_all_contents
      Pathname.stub(:pwd, @root_dir) do
        @config, @options = build_config_options_objects(LoaderTest, {
          sideload: true,
          current: true
        }, false)
      end
      loader = Loader.new(config: @config)
      loader.build(options: @options)
      file_path = File.join(@config.out[:folder], Manifest.new(config: @config).build_version+".zip")
      Zip::File.open(file_path) do |file|
        assert file.find_entry("manifest") != nil
        assert file.find_entry("a") != nil
        assert file.find_entry("source/b") != nil
        assert file.find_entry("source/c/d") != nil
      end
      FileUtils.rm(file_path)
    end

    def test_loader_unload
      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}/plugin_install").
        to_return(status: 200, body: "Delete Succeeded", headers: {}))

      loader = Loader.new(config: @config)
      loader.delete(options: @options)
    end
    def test_loader_unload_fail
      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}/plugin_install").
        to_return(status: 200, body: "Delete Failed", headers: {}))

      loader = Loader.new(config: @config)
      assert_raises ExecutionError do
        loader.delete(options: @options)
      end
    end
    def test_loader_squash
      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}/plugin_install").
        to_return(status: 200, body: "Conversion succeeded", headers: {}))

      loader = Loader.new(config: @config)
      loader.squash(options: @options)
    end
    def test_loader_squash_fail
      @request_stubs.push(stub_request(:post, "http://#{@device_config[:ip]}/plugin_install").
        to_return(status: 200, body: "Conversion failed", headers: {}))

      loader = Loader.new(config: @config)
      assert_raises ExecutionError do
        loader.squash(options: @options)
      end
    end
    def test_copy_files
      loader = Loader.new(config: @config)
      Dir.mktmpdir do |dir|
        loader.copy(options: @options, path: dir)
        assert File.exist?(File.join(dir, "manifest"))
        assert File.exist?(File.join(dir, "source", "b"))
        assert File.exist?(File.join(dir, "source", "c", "d"))
      end
    end
  end
end
