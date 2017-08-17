# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class ScripterTest < Minitest::Test
    def setup
      options = {print: "field", working: true}
      RokuBuilder.setup_plugins
      unless RokuBuilder.plugins.include?(Scripter)
        RokuBuilder.register_plugin(Scripter)
      end
      @config, @options = build_config_options_objects(ScripterTest, options, false)
    end
    def test_scripter_parse_options_long
      parser = OptionParser.new
      options = {}
      Scripter.parse_options(parser: parser, options: options)
      argv = ["roku", "--print", "print"]
      parser.parse! argv
      assert_equal :print, options[:print]
    end
    def test_scripter_print_bad_attr
      scripter = Scripter.new(config: @config)
      assert_raises ExecutionError do
        scripter.print(options: @options)
      end
    end

    def test_scripter_print_config_root_dir
      options = {print: :root_dir, working: true}
      @config, @options = build_config_options_objects(ScripterTest, options, false)
      call_count = 0
      fake_print = lambda { |message, path|
        assert_equal "%s", message
        assert_equal @config.parsed[:root_dir], path
        call_count+=1
      }
      scripter = Scripter.new(config: @config)
      scripter.stub(:printf, fake_print) do
        scripter.print(options: @options)
      end
      assert_equal 1, call_count
    end
    def test_scripter_print_config_app_name
      options = {print: :app_name, working: true}
      @config, @options = build_config_options_objects(ScripterTest, options, false)
      call_count = 0
      fake_print = lambda { |message, value|
        assert_equal "%s", message
        assert_equal "<app name>", value
        call_count+=1
      }
      scripter = Scripter.new(config: @config)
      scripter.stub(:printf, fake_print) do
        scripter.print(options: @options)
      end
      assert_equal 1, call_count
    end

    def test_scripter_print_manifest_title
      options = {print: :title, working: true}
      @config, @options = build_config_options_objects(ScripterTest, options, false)
      call_count = 0
      fake_print = lambda { |message, title|
        assert_equal "%s", message
        assert_equal "Test", title
        call_count+=1
      }
      scripter = Scripter.new(config: @config)
      scripter.stub(:printf, fake_print) do
        scripter.print(options: @options)
      end
      assert_equal 1, call_count
    end

    def test_scripter_print_manifest_build_version
      options = {print: :build_version, working: true}
      @config, @options = build_config_options_objects(ScripterTest, options, false)
      call_count = 0
      fake_print = lambda { |message, build|
        assert_equal "%s", message
        assert_equal "010101.1", build
        call_count+=1
      }
      scripter = Scripter.new(config: @config)
      scripter.stub(:printf, fake_print) do
        scripter.print(options: @options)
      end
      assert_equal 1, call_count
    end

    def test_scripter_print_manifest_app_version
      options = {print: :app_version, working: true}
      @config, @options = build_config_options_objects(ScripterTest, options, false)
      call_count = 0
      fake_print = lambda { |message, major, minor|
        assert_equal "%s.%s", message
        assert_equal "1", major
        assert_equal "0", minor
        call_count+=1
      }
      scripter = Scripter.new(config: @config)
      scripter.stub(:printf, fake_print) do
        scripter.print(options: @options)
      end
      assert_equal 1, call_count
    end
  end
end
