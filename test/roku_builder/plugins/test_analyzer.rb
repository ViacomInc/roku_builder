# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class AnalyzerTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Analyzer)
      @config, @options = build_config_options_objects(AnalyzerTest, {analyze: true, working: true}, false)
      @root_dir = @config.root_dir
      @device_config = @config.device_config
      FileUtils.cp(File.join(@root_dir, "manifest_template"), File.join(@root_dir, "manifest"))
      @request_stubs = []
      analyzer_config = nil
      File.open(File.join(@root_dir, "analyzer_config.json")) do |file|
        analyzer_config = file.read
      end
      @request_stubs.push(stub_request(:get, "http://devtools.web.roku.com/static-code-analyzer/config.json").
        to_return(status: 200, body: analyzer_config, headers: {}))
      folder = File.join(@root_dir, "source")
      Dir.mkdir(folder) unless File.exist?(folder)
    end
    def teardown
      manifest = File.join(@root_dir, "manifest")
      FileUtils.rm(manifest) if File.exist?(manifest)
      linter_config = File.join(@root_dir, ".roku_builder_linter.json")
      FileUtils.rm(linter_config) if File.exist?(linter_config)
      @request_stubs.each {|req| remove_request_stub(req)}
    end
    def test_analyzer_parse_commands
      parser = OptionParser.new
      options = {}
      Analyzer.parse_options(parser: parser, options: options)
      argv = ["roku", "--analyze"]
      parser.parse! argv
      assert options[:analyze]
    end
    def test_clean_app
      warnings = test
      assert_equal Array, warnings.class
      assert_equal 0, warnings.count
    end
    def test_performance_aa_does_exist
      warnings = test_file(text: "exists = aa.doesExist(\"test\")")
      assert_equal 1, warnings.count
      assert_match(/DoesExist check/, warnings[0][:message])
    end
    def test_performance_aa_string_ref
      warnings = test_file(text: "aa[\"test\"] = \"test\"")
      assert_equal 1, warnings.count
      assert_match(/String reference/, warnings[0][:message])
    end
    def test_performance_for_loop
      warnings = test_file(text: "FOR i=0 TO 10\n ? i\nEND FOR")
      assert_equal 1, warnings.count
      assert_match(/For loop found/, warnings[0][:message])
    end
    def test_performance_for_loop_lower_case
      warnings = test_file(text: "for i=0 to 10\n ? i\nEND FOR")
      assert_equal 1, warnings.count
      assert_match(/For loop found/, warnings[0][:message])
    end
    def test_performance_for_loop_title_case
      warnings = test_file(text: "For i=0 To 10\n ? i\nEND FOR")
      assert_equal 1, warnings.count
      assert_match(/For loop found/, warnings[0][:message])
    end
    def test_performance_regex
      warnings = test_file(text: "\"roRegex\"")
      assert_equal 1, warnings.count
      assert_match(/Regexp found/, warnings[0][:message])
    end
    def test_library_skip
      set_config({libraries: ["/source/test.brs"]})
      warnings = test_file(text: "\"roRegex\"")
      puts warnings
      assert_equal 0, warnings.count
    end
    def test_library_skip_folder
      set_config({libraries: ["/source"]})
      warnings = test_file(text: "\"roRegex\"")
      assert_equal 0, warnings.count
    end
    def test_library_include
      @config, @options = build_config_options_objects(AnalyzerTest, {analyze: true, working: true, include_libraries: true}, false)
      set_config({libraries: ["/source/test.brs"]})
      warnings = test_file(text: "\"roRegex\"")
      assert_equal 1, warnings.count
    end
    def test_performance_skip_warning_comment
      warnings = test_file(text: "function test() as String 'ignore-warning\n? \"test\"\nend function")
      assert_equal 0, warnings.count
    end
    def test_performance_skip_warning_comment_upper_case
      warnings = test_file(text: "function test() as String 'IGNORE-WARNING\n? \"test\"\nend function")
      assert_equal 0, warnings.count
    end
    def test_performance_for_each_loop_title_case
      warnings = test_file(text: "For each button in buttons\n ? button\nEND FOR")
      assert_equal 0, warnings.count
    end
    def test_linter_checks
      set_linter_config("dont_use_hello_world.json")
      warnings = test_file(text: "hello world")
      assert_equal 1, warnings.count
    end
    def test_linter_positive_match
      set_linter_config("linter_positive_match.json")
      warnings = test_file(text: "hello world\nhello moon")
      assert_equal 1, warnings.count
      assert_equal 1, warnings.first[:line]
    end


    private

    def set_linter_config(config_file = nil)
      if config_file
        FileUtils.cp(File.join(@root_dir, config_file), File.join(@root_dir, ".roku_builder_linter.json"))
      end
    end

    def test_manifest(manifest_file = nil)
      if manifest_file
        use_manifest(manifest_file)
      end
      test
    end

    def use_manifest(manifest_file)
      FileUtils.cp(File.join(@root_dir, manifest_file), File.join(@root_dir, "manifest"))
    end

    def test_file(text:, file: nil, quiet: true)
      file ||= "test.brs"
      test_file = File.join(@root_dir, "source", file)
      File.open(test_file, "w") do |file|
        file.write(text)
      end
      warnings = test(quiet)
      FileUtils.rm(test_file) if File.exist?(test_file)
      warnings
    end

    def test_logger_with_file_content(text:, severity:)
      logger = Minitest::Mock.new

      logger.expect(:level=, nil, [Integer])
      logger.expect(:formatter=, nil, [Proc])
      logger.expect(severity, nil, [String])

      ::Logger.stub :new, logger do
        warnings = test_file(text: text, quiet: false)
      end

      logger.verify
      warnings
    end

    def test(quiet=true)
      analyzer = Analyzer.new(config: @config)
      analyzer.analyze(options: @options, quiet: quiet)
    end

    def set_config(config_content)
      @config.project.merge!(config_content)
    end

    def print_all(warnings)
      warnings.each do |warning|
        puts warning[:message]
      end
    end
  end
end

