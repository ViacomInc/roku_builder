# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class StagerTest < Minitest::Test

  def test_stager_method
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    stager_config = {
      method: :working,
      root_dir: root_dir,
      logger: nil
    }
    stager = RokuBuilder::Stager.new(**stager_config)
    assert_equal stager_config[:method], stager.method
  end

  def test_stager_stage_working
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    stager_config = {
      method: :working,
      root_dir: root_dir,
      logger: nil
    }
    stager = RokuBuilder::Stager.new(**stager_config)
    assert stager.stage
    assert stager.unstage
  end

  def test_stager_stage_current
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    stager_config = {
      method: :current,
      root_dir: root_dir,
      logger: nil
    }
    stager = RokuBuilder::Stager.new(**stager_config)
    assert stager.stage
    assert stager.unstage
  end

  def test_stager_stage_git_stash
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    branch_name = 'branch'
    git = Minitest::Mock.new
    branch = Minitest::Mock.new
    stashes = Minitest::Mock.new

    stager_config = {
      method: :git,
      root_dir: root_dir,
      key: branch_name,
      logger: nil
    }

    git.expect(:current_branch, 'other_branch')
    git.expect(:current_branch, 'other_branch')
    git.expect(:branch, branch)
    branch.expect(:stashes, stashes)
    stashes.expect(:save, true, ["roku-builder-temp-stash"])
    git.expect(:checkout, nil, [branch_name])
    git.expect(:checkout, nil, ['other_branch'])
    git.expect(:branch, branch)
    branch.expect(:stashes, stashes)
    stashes.expect(:apply, nil)

    Git.stub(:open, git) do
      stager = RokuBuilder::Stager.new(**stager_config)
      assert stager.stage
      assert stager.unstage
    end
    git.verify
    branch.verify
    stashes.verify
  end

  def test_stager_stage_git_no_stash
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    branch_name = 'branch'
    git = Minitest::Mock.new
    branch = Minitest::Mock.new
    stashes = Minitest::Mock.new

    stager_config = {
      method: :git,
      root_dir: root_dir,
      key: branch_name,
      logger: nil
    }

    git.expect(:current_branch, 'other_branch')
    git.expect(:current_branch, 'other_branch')
    git.expect(:branch, branch)
    branch.expect(:stashes, stashes)
    stashes.expect(:save, nil, ["roku-builder-temp-stash"])
    git.expect(:checkout, nil, [branch_name])
    git.expect(:checkout, nil, ['other_branch'])

    Git.stub(:open, git) do
      stager = RokuBuilder::Stager.new(**stager_config)
      assert stager.stage
      assert stager.unstage
    end
    git.verify
    branch.verify
    stashes.verify
  end

  def test_stager_stage_git_error_stage
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    branch_name = 'branch'
    git = Minitest::Mock.new
    branch = Minitest::Mock.new
    stashes = Minitest::Mock.new
    logger = Minitest::Mock.new

    stager_config = {
      method: :git,
      root_dir: root_dir,
      key: branch_name,
      logger: logger
    }

    def git.checkout(branch)
      raise Git::GitExecuteError.new
    end

    git.expect(:current_branch, 'other_branch')
    git.expect(:current_branch, 'other_branch')
    git.expect(:branch, branch)
    branch.expect(:stashes, stashes)
    stashes.expect(:save, true, ["roku-builder-temp-stash"])
    logger.expect(:error, nil, ["Branch or ref does not exist"])
    git.expect(:branch, branch)
    branch.expect(:stashes, stashes)
    stashes.expect(:apply, nil)

    Git.stub(:open, git) do
      stager = RokuBuilder::Stager.new(**stager_config)
      assert !stager.stage
      assert stager.unstage
    end
    git.verify
    branch.verify
    stashes.verify
    logger.verify
  end

  def test_stager_stage_git_error_unstage
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    branch_name = 'branch'
    git = Minitest::Mock.new
    branch = Minitest::Mock.new
    stashes = Minitest::Mock.new
    logger = Minitest::Mock.new

    stager_config = {
      method: :git,
      root_dir: root_dir,
      key: branch_name,
      logger: logger
    }

    def git.checkout(branch)
      raise Git::GitExecuteError.new
    end

    logger.expect(:error, nil, ["Branch or ref does not exist"])

    Git.stub(:open, git) do
      stager = RokuBuilder::Stager.new(**stager_config)
      stager.instance_variable_set(:@current_branch, "branch")
      assert !stager.unstage
    end
    logger.verify
  end

  def test_stager_stage_script
    root_dir = File.join(File.dirname(__FILE__), "test_files", "stager_test")
    stager_config = {
      method: :script,
      key: {stage: "stage_script", unstage: "unstage_script"},
      root_dir: root_dir,
      logger: nil
    }
    RokuBuilder::Controller.stub(:system, nil) do
      stager = RokuBuilder::Stager.new(**stager_config)
      assert stager.stage
      assert stager.unstage
    end
  end
end

