# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class GitTest < Minitest::Test

  def test_stashes_pop
    base = Minitest::Mock.new
    lib = Minitest::Mock.new

    index = 1
    base.expect(:lib, lib)
    base.expect(:lib, lib)
    lib.expect(:stashes_all, [])
    lib.expect(:stash_pop, nil, [index])

    Dir.mktmpdir do |dir|
      stashes = Git::Stashes.new(base)
      stashes.pop(index)
    end

    base.verify
    lib.verify
  end

  def test_stashes_drop
    base = Minitest::Mock.new
    lib = Minitest::Mock.new

    index = 1
    base.expect(:lib, lib)
    base.expect(:lib, lib)
    lib.expect(:stashes_all, [])
    lib.expect(:stash_drop, nil, [index])

    Dir.mktmpdir do |dir|
      stashes = Git::Stashes.new(base)
      stashes.drop(index)
    end

    base.verify
    lib.verify
  end

  def test_lib_pop
    lib = Git::Lib.new
    command = lambda{|command_sent|
      assert_equal "stash pop", command_sent
    }
    lib.stub(:command, command) do
      lib.stash_pop
    end

    lib = Git::Lib.new
    command = lambda{|command_sent, args|
      assert_equal "stash pop", command_sent
      assert_equal [1], args
    }
    lib.stub(:command, command) do
      lib.stash_pop(1)
    end
  end

  def test_lib_drop
    lib = Git::Lib.new
    command = lambda{|command_sent|
      assert_equal "stash drop", command_sent
    }
    lib.stub(:command, command) do
      lib.stash_drop
    end

    lib = Git::Lib.new
    command = lambda{|command_sent, args|
      assert_equal "stash drop", command_sent
      assert_equal [1], args
    }
    lib.stub(:command, command) do
      lib.stash_drop(1)
    end
  end
end
