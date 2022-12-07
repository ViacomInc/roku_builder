# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class ConfigParserTest < Minitest::Test
    def setup
      Logger.set_testing
    end
    def test_manifest_config
      options = build_options({
        validate: true,
        working: true
      })
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      configs = ConfigParser.parse(options: options, config: config)

      assert_equal Hash, config.class
      assert_equal test_files_path(ConfigParserTest), configs[:root_dir]
    end

    def test_manifest_config_in
      options = build_options({
        in: "/dev/null/infile",
        validate: true
      })
      config = good_config(ConfigParserTest)
      configs = ConfigParser.parse(options: options, config: config)

      assert_equal Hash, config.class
      assert_equal "/dev/null/infile", configs[:root_dir]
    end

    def test_manifest_config_in_expand
      options = build_options({
        in: "./infile",
        validate: true
      })
      config = good_config(ConfigParserTest)
      configs = ConfigParser.parse(options: options, config: config)

      assert_equal Hash, config.class
      assert_equal File.join(Dir.pwd, "infile"), configs[:root_dir]
    end

    def test_manifest_config_current
      options = build_options({
        current: true,
        validate: true
      })
      options.define_singleton_method(:source_commands){[:validate]}
      configs = nil
      config = good_config(ConfigParserTest)
      Pathname.stub(:pwd, "/dev/null/infile") do
        File.stub(:exist?, true) do
          configs = ConfigParser.parse(options: options, config: config)
        end
      end

      assert_equal Hash, config.class
      assert_equal "/dev/null/infile", configs[:root_dir]
    end

    def test_setup_project_config_bad_project
      config = good_config(ConfigParserTest)
      options = build_options({validate: true, project: :project3, stage: "production"})
      options.define_singleton_method(:source_commands) {[:validate]}
      assert_raises ParseError do
        File.stub(:exist?, true) do
          ConfigParser.parse(options: options, config: config)
        end
      end
    end

    def test_setup_project_config_current
      options = build_options({ validate: true, current: true })
      config = good_config(ConfigParserTest)
      configs = nil
      File.stub(:exist?, true) do
        configs = ConfigParser.parse(options: options, config: config)
      end
      project = configs[:project]
      assert_equal Pathname.pwd.to_s, project[:directory]
      assert_equal :current, project[:stage_method]
      assert_nil project[:folders]
      assert_nil project[:files]
    end

    def test_setup_project_config_good_project_dir
      config = good_config(ConfigParserTest)
      options = build_options({validate: true, project: :project1, stage: 'production'})
      options.define_singleton_method(:source_commands) {[:validate]}
      File.stub(:exist?, true) do
        ConfigParser.parse(options: options, config: config)
      end
    end

    def test_setup_project_config_bad_project_dir
      config = good_config(ConfigParserTest)
      config[:projects][:project1][:directory] = "/dev/null"
      options = build_options({validate: true, project: :project1, working: true})
      options.define_singleton_method(:source_commands){[:validate]}
      assert_raises ParseError do
        File.stub(:exist?, true) do
          ConfigParser.parse(options: options, config: config)
        end
      end
    end

    def test_setup_project_config_bad_child_project_dir
      config = good_config(ConfigParserTest)
      config[:projects][:project_dir] = "/tmp"
      config[:projects][:project1][:directory] = "bad"
      options = build_options({validate: true, project: :project1, working: true})
      options.define_singleton_method(:source_commands){[:validate]}
      assert_raises ParseError do
        File.stub(:exist?, true) do
          ConfigParser.parse(options: options, config: config)
        end
      end
    end

    def test_setup_project_config_bad_parent_project_dir
      config = good_config(ConfigParserTest)
      config[:projects][:project_dir] = "/bad"
      config[:projects][:project1][:directory] = "good"
      options = build_options({validate: true, project: :project1, stage: 'production'})
      options.define_singleton_method(:source_commands){[:validate]}
      assert_raises ParseError do
        File.stub(:exist?, true) do
          ConfigParser.parse(options: options, config: config)
        end
      end
    end

    def test_setup_stage_config_script
      config = good_config(ConfigParserTest)
      config[:projects][:project1][:stage_method] = :script
      config[:projects][:project1][:stages][:production][:script] = {stage: "script", unstage: "script"}
      options = build_options({stage: "production", validate: true})
      options.define_singleton_method(:source_commands){[:validate]}
      parsed = ConfigParser.parse(options: options, config: config)
      assert_equal parsed[:project][:stages][:production][:script], config[:projects][:project1][:stages][:production][:script]
    end

    def test_manifest_config_project_select
      options = build_options({ validate: true, working: true })
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      configs = nil
      Pathname.stub(:pwd, Pathname.new("/dev/nuller")) do
        configs = ConfigParser.parse(options: options, config: config)
      end
      assert_equal Hash, config.class
      assert_equal test_files_path(ConfigParserTest), configs[:project][:directory]
    end

    def test_manifest_config_project_directory
      options = build_options({
        validate: true,
        working: true
      })
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:projects][:project_dir] = "/tmp"
      config[:projects][:project1][:directory] = "project1"
      config[:projects][:project2][:directory] = "project2"

      configs = nil

      Dir.stub(:exist?, true) do
        configs = ConfigParser.parse(options: options, config: config)
      end

      assert_equal Hash, config.class
      assert_equal "/tmp/project1", configs[:project][:directory]
    end

    def test_manifest_config_project_directory_select
      options = build_options({validate: true, working: true})
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:projects][:project_dir] = "/tmp"
      config[:projects][:project1][:directory] = "project1"
      config[:projects][:project2][:directory] = "project2"

      configs = nil
      Pathname.stub(:pwd, Pathname.new("/tmp/project2").realdirpath) do
        Dir.stub(:exist?, true) do
          configs = ConfigParser.parse(options: options, config: config)
        end
      end

      assert_equal Hash, config.class
      assert_equal "/tmp/project2", configs[:project][:directory]
    end

    def test_manifest_config_project_directory_select_full_path
      options = build_options({validate: true, working: true})
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:projects][:project_dir] = "/tmp"
      config[:projects][:project1][:directory] = "/tmp/project1"

      configs = nil
      Pathname.stub(:pwd, Pathname.new("/tmp/project1")) do
        Dir.stub(:exist?, true) do
          configs = ConfigParser.parse(options: options, config: config)
        end
      end

      assert_equal Hash, config.class
      assert_equal "/tmp/project1", configs[:project][:directory]
    end

    def test_key_config_key_directory
      tmp_file = Tempfile.new("pkg")
      options = build_options({validate: true, project: :project2, stage: 'production'})
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:keys][:key_dir] = File.dirname(tmp_file.path)
      config[:keys][:a][:keyed_pkg] = File.basename(tmp_file.path)

      configs = ConfigParser.parse(options: options, config: config)

      assert_equal Hash, config.class
      assert_equal tmp_file.path, configs[:key][:keyed_pkg]
      tmp_file.close
    end

    def test_key_config_key_local_directory
      tmp_file = Tempfile.new("pkg")
      FileUtils.touch("./pkg")
      options = build_options({validate: true, project: :project2, stage: 'production'})
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:keys][:key_dir] = File.dirname(tmp_file.path)
      config[:keys][:a][:keyed_pkg] = "./pkg"

      configs = ConfigParser.parse(options: options, config: config)

      assert_equal Hash, config.class
      assert_equal "./pkg", configs[:key][:keyed_pkg]
      tmp_file.close
      FileUtils.rm("./pkg")
    end

    def test_key_config_key_directory_bad
      tmp_file = Tempfile.new("pkg")
      options = build_options({validate: true, project: :project2, stage: 'production'})
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:keys][:key_dir] = "/bad"
      config[:keys][:a][:keyed_pkg] = File.basename(tmp_file.path)

      assert_raises ParseError do
        ConfigParser.parse(options: options, config: config)
      end
    end

    def test_key_config_key_path_bad
      tmp_file = Tempfile.new("pkg")
      options = build_options({validate: true, project: :project2, stage: 'production'})
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:keys][:key_dir] = File.dirname(tmp_file.path)
      config[:keys][:a][:keyed_pkg] = File.basename(tmp_file.path)+".bad"

      assert_raises ParseError do
        ConfigParser.parse(options: options, config: config)
      end
    end
    def test_key_config_bad_key
      options = build_options({validate: true, project: :project1, stage: 'production', })
      options.define_singleton_method(:source_commands){[:validate]}
      config = good_config(ConfigParserTest)
      config[:projects][:project1][:stages][:production][:key] = "bad"

      assert_raises ParseError do
        ConfigParser.parse(options: options, config: config)
      end
    end
    def test_outfile_config_default
      config = good_config(ConfigParserTest)
      options = build_options({validate: true, working: true, out: nil})
      parsed = ConfigParser.parse(options: options, config: config)

      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      assert_nil parsed[:out][:file]
      assert_equal tmp_folder, parsed[:out][:folder]
    end
    def test_outfile_config_folder
      config = good_config(ConfigParserTest)
      options = build_options({validate: true, working: true, out: "/home/user"})
      options.define_singleton_method(:source_commands){[:validate]}
      parsed = ConfigParser.parse(options: options, config: config)
      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      assert_nil parsed[:out][:file]
      assert_equal "/home/user", parsed[:out][:folder]
    end
    def test_outfile_config_pkg
      config = good_config(ConfigParserTest)

      options = build_options({validate: true, working: true, out: "/home/user/file.pkg"})
      parsed = ConfigParser.parse(options: options, config: config)
      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      refute_nil parsed[:out][:file]
      assert_equal "/home/user", parsed[:out][:folder]
      assert_equal "file.pkg", parsed[:out][:file]
    end
    def test_outfile_config_zip
      config = good_config(ConfigParserTest)

      options = build_options({validate: true, working: true, out: "/home/user/file.zip"})
      parsed = ConfigParser.parse(options: options, config: config)
      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      refute_nil parsed[:out][:file]
      assert_equal "/home/user", parsed[:out][:folder]
      assert_equal "file.zip", parsed[:out][:file]
    end
    def test_outfile_config_jpg
      config = good_config(ConfigParserTest)

      options = build_options({validate: true, working: true, out: "/home/user/file.jpg"})
      parsed = ConfigParser.parse(options: options, config: config)
      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      refute_nil parsed[:out][:file]
      assert_equal "/home/user", parsed[:out][:folder]
      assert_equal "file.jpg", parsed[:out][:file]
    end
    def test_outfile_config_default_jpg
      config = good_config(ConfigParserTest)

      options = build_options({validate: true, working: true, out: "file.jpg"})
      parsed = ConfigParser.parse(options: options, config: config)
      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      refute_nil parsed[:out][:file]
      assert_equal tmp_folder, parsed[:out][:folder]
      assert_equal "file.jpg", parsed[:out][:file]
    end
    def test_outfile_config_config_out
      config = good_config(ConfigParserTest)
      config[:out] = "/home/user"
      options = build_options({validate: true, working: true, out: nil})
      parsed = ConfigParser.parse(options: options, config: config)

      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      assert_nil parsed[:out][:file]
      assert_equal "/home/user", parsed[:out][:folder]
    end
    def test_outfile_config_config_out_file
      config = good_config(ConfigParserTest)
      config[:out] = "/home/user/file.pkg"
      options = build_options({validate: true, working: true, out: nil})
      parsed = ConfigParser.parse(options: options, config: config)

      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      refute_nil parsed[:out][:file]
      assert_equal "/home/user", parsed[:out][:folder]
      assert_equal "file.pkg", parsed[:out][:file]
    end
    def test_outfile_config_config_and_option_out
      config = good_config(ConfigParserTest)
      config[:out] = "/home/user"
      options = build_options({validate: true, working: true, out: "/home/user2"})
      parsed = ConfigParser.parse(options: options, config: config)

      refute_nil parsed[:out]
      refute_nil parsed[:out][:folder]
      assert_nil parsed[:out][:file]
      assert_equal "/home/user2", parsed[:out][:folder]
    end
  end
end
