# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class StagerTest < Minitest::Test
    def setup
      Logger.set_testing
    end

    def build_config_options(options)
      @options = build_options(options)
      @options.define_singleton_method(:source_commands) {[:validate]}
      @config = RokuBuilder::Config.new(options: @options)
      @config.instance_variable_set(:@config, good_config(StagerTest))
      @config.parse
    end

    def test_stager_method
      build_config_options({validate: true, working: true})
      stager = Stager.new(config: @config, options: @options)
      assert_equal :working, stager.method
    end

    def test_stager_stage_working
      build_config_options({validate: true, working: true})
      stager = Stager.new(config: @config, options: @options)
      assert stager.stage
      assert stager.unstage
    end

    def test_stager_stage_current
      Pathname.stub(:pwd, test_files_path(StagerTest)) do
        build_config_options({validate: true, current: true})
      end
      stager = Stager.new(config: @config, options: @options)
      assert stager.stage
      assert stager.unstage
    end

    def test_stager_stage_in
      in_file = File.join(test_files_path(StagerTest), "test.zip")
      build_config_options({validate: true, in: in_file})
      stager = Stager.new(config: @config, options: @options)
      assert stager.stage
      assert stager.unstage
    end

    def test_stager_stage_git_stash
      branch_name = 'production'
      build_config_options({validate: true, stage: "production"})
      git = Minitest::Mock.new
      branch = Minitest::Mock.new
      stashes = Minitest::Mock.new
      stash = Minitest::Mock.new

      git.expect(:current_branch, 'other_branch')
      git.expect(:current_branch, 'other_branch')
      git.expect(:branch, branch)
      branch.expect(:stashes, stashes)
      stashes.expect(:save, true, ["roku-builder-temp-stash"])
      git.expect(:checkout, nil, [branch_name])
      git.expect(:branch, branch)
      branch.expect(:stashes, [stash])
      git.expect(:checkout, nil, ['other_branch'])
      git.expect(:branch, branch)
      stash.expect(:message, "roku-builder-temp-stash")
      branch.expect(:stashes, stashes)
      stashes.expect(:pop, nil, ["stash@{0}"])

      Git.stub(:open, git) do
        stager = Stager.new(config: @config, options: @options)
        assert stager.stage
        assert stager.unstage
      end
      git.verify
      branch.verify
      stashes.verify
      stash.verify
    end

    def test_stager_stage_git_no_stash
      branch_name = 'production'
      build_config_options({validate: true, stage: "production"})
      git = Minitest::Mock.new
      branch = Minitest::Mock.new
      stashes = Minitest::Mock.new

      git.expect(:current_branch, 'other_branch')
      git.expect(:current_branch, 'other_branch')
      git.expect(:branch, branch)
      branch.expect(:stashes, stashes)
      stashes.expect(:save, nil, ["roku-builder-temp-stash"])
      git.expect(:checkout, nil, [branch_name])

      git.expect(:checkout, nil, ['other_branch'])
      git.expect(:branch, branch)
      branch.expect(:stashes, [])

      Git.stub(:open, git) do
        stager = Stager.new(config: @config, options: @options)
        assert stager.stage
        assert stager.unstage
      end
      git.verify
      branch.verify
      stashes.verify
    end

    def test_stager_stage_git_error_stage
      build_config_options({validate: true, stage: "production"})
      git = Minitest::Mock.new
      branch = Minitest::Mock.new
      stashes = Minitest::Mock.new
      stash = Minitest::Mock.new

      def git.checkout(branch)
        raise Git::GitExecuteError.new
      end

      git.expect(:current_branch, 'other_branch')
      git.expect(:current_branch, 'other_branch')
      git.expect(:branch, branch)
      branch.expect(:stashes, stashes)
      stashes.expect(:save, true, ["roku-builder-temp-stash"])
      git.expect(:branch, branch)
      branch.expect(:stashes, [stash])
      git.expect(:branch, branch)
      stash.expect(:message, "roku-builder-temp-stash")
      branch.expect(:stashes, stashes)
      stashes.expect(:pop, nil, ["stash@{0}"])

      Git.stub(:open, git) do
        stager = Stager.new(config: @config, options: @options)
        assert !stager.stage
        assert stager.unstage
      end
      git.verify
      branch.verify
      stashes.verify
      stash.verify
    end

    def test_stager_stage_git_error_unstage
      build_config_options({validate: true, stage: "production"})
      git = Minitest::Mock.new
      logger = Minitest::Mock.new

      Logger.class_variable_set(:@@instance, logger)

      def git.checkout(branch)
        raise Git::GitExecuteError.new
      end

      logger.expect(:error, nil, ["Branch or ref does not exist"])

      Git.stub(:open, git) do
        stager = Stager.new(config: @config, options: @options)
        stager.instance_variable_set(:@current_branch, "branch")
        assert !stager.unstage
      end
      git.verify
      logger.verify
      Logger.set_testing
    end

    def test_stager_save_state
      branch_name = 'production'
      build_config_options({validate: true, stage: "production"})
      git = Minitest::Mock.new
      branch = Minitest::Mock.new
      stashes = Minitest::Mock.new
      pstore = Minitest::Mock.new

      git.expect(:current_branch, 'other_branch')
      git.expect(:current_branch, 'other_branch')
      git.expect(:branch, branch)
      branch.expect(:stashes, stashes)
      stashes.expect(:save, 'stash', ["roku-builder-temp-stash"])
      git.expect(:checkout, nil, [branch_name])

      pstore.expect(:transaction, nil) do |&block|
      block.call
      end
      pstore.expect(:[]=, nil, [:current_branch, 'other_branch'])


      Git.stub(:open, git) do
        PStore.stub(:new, pstore) do
          stager = Stager.new(config: @config, options: @options)
          assert stager.stage
        end
      end
      git.verify
      branch.verify
      stashes.verify
      pstore.verify
    end

    def test_stager_load_state
      build_config_options({validate: true, stage: "production"})
      git = Minitest::Mock.new
      branch = Minitest::Mock.new
      stashes = Minitest::Mock.new
      stash = Minitest::Mock.new
      pstore = Minitest::Mock.new

      pstore.expect(:transaction, nil) do |&block|
      block.call
      end
      git.expect(:branches, ['other_branch'])
      pstore.expect(:[], 'other_branch', [:current_branch])
      pstore.expect(:[]=, nil, [:current_branch, nil])

      git.expect(:branch, branch)
      branch.expect(:stashes, [stash])
      git.expect(:checkout, nil, ['other_branch'])
      git.expect(:branch, branch)
      stash.expect(:message, "roku-builder-temp-stash")
      branch.expect(:stashes, stashes)
      stashes.expect(:pop, nil, ["stash@{0}"])

      Git.stub(:open, git) do
        PStore.stub(:new, pstore) do
          stager = Stager.new(config: @config, options: @options)
          assert stager.unstage
        end
      end
      git.verify
      branch.verify
      stashes.verify
      stash.verify
      pstore.verify
    end

    def test_stager_load_second_state
      build_config_options({validate: true, stage: "production"})
      git = Minitest::Mock.new
      branch = Minitest::Mock.new
      stashes = Minitest::Mock.new
      stash = Minitest::Mock.new
      other_stash = Minitest::Mock.new
      pstore = Minitest::Mock.new

      pstore.expect(:transaction, nil) do |&block|
      block.call
      end
      git.expect(:branches, ['other_branch'])
      pstore.expect(:[], 'other_branch', [:current_branch])
      pstore.expect(:[]=, nil, [:current_branch, nil])

      git.expect(:branch, branch)
      branch.expect(:stashes, [other_stash, stash])
      git.expect(:checkout, nil, ['other_branch'])
      git.expect(:branch, branch)
      stash.expect(:message, "roku-builder-temp-stash")
      other_stash.expect(:message, "random_messgae")
      branch.expect(:stashes, stashes)
      stashes.expect(:pop, nil, ["stash@{1}"])

      Git.stub(:open, git) do
        PStore.stub(:new, pstore) do
          stager = Stager.new(config: @config, options: @options)
          assert stager.unstage
        end
      end
      git.verify
      branch.verify
      stashes.verify
      stash.verify
      other_stash.verify
      pstore.verify
    end
    def test_stager_stage_script
      build_config_options({validate: true, stage: "production", project: "project2"})
      RokuBuilder.stub(:system, nil) do
        stager = Stager.new(config: @config, options: @options)
        assert stager.stage
        assert stager.unstage
      end
    end

  end
end
