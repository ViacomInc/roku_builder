# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class TesterTest < Minitest::Test
  def test_tester_runtests
    connection = Minitest::Mock.new
    loader = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    loader_config = {
      root_dir: "root/dir/path",
      branch: "branch",
      folders: ["source"],
      files: ["manifest"]
    }
    tester = RokuBuilder::Tester.new(**device_config)

    loader.expect(:sideload, nil, [loader_config])
    connection.expect(:waitfor, nil, [/\*\*\*\*\* ENDING TESTS \*\*\*\*\*/])
    connection.expect(:puts, nil, ["cont\n"])

    RokuBuilder::Loader.stub(:new, loader) do
      Net::Telnet.stub(:new, connection) do
        tester.run_tests(sideload_config: loader_config)
      end
    end

    connection.verify
  end

  def test_tester_runtests_and_handle
    waitfor = Proc.new do |end_reg, &blk|
      assert_equal /\*\*\*\*\* ENDING TESTS \*\*\*\*\*/, end_reg
      txt = "Fake Text"
      blk.call(txt) == false
    end
    connection = Minitest::Mock.new
    loader = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    loader_config = {
      root_dir: "root/dir/path",
      branch: "branch",
      folders: ["source"],
      files: ["manifest"]
    }
    tester = RokuBuilder::Tester.new(**device_config)

    loader.expect(:sideload, nil, [loader_config])
    connection.expect(:waitfor, nil, &waitfor)
    connection.expect(:puts, nil, ["cont\n"])

    RokuBuilder::Loader.stub(:new, loader) do
      Net::Telnet.stub(:new, connection) do
        tester.stub(:handle_text, false) do
          tester.run_tests(sideload_config: loader_config)
        end
      end
    end

    connection.verify
  end

  def test_tester_handle_text_no_text
    logger = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: logger
    }
    tester = RokuBuilder::Tester.new(**device_config)

    text = "this\nis\na\ntest\nparagraph"

    assert !tester.send(:handle_text, {txt: text, in_tests: false})

    logger.verify
  end

  def test_tester_handle_text_all_text
    logger = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: logger
    }
    tester = RokuBuilder::Tester.new(**device_config)

    text = "this\nis\na\ntest\nparagraph"

    logger.expect(:unknown, nil, ["this"])
    logger.expect(:unknown, nil, ["is"])
    logger.expect(:unknown, nil, ["a"])
    logger.expect(:unknown, nil, ["test"])
    logger.expect(:unknown, nil, ["paragraph"])

    assert tester.send(:handle_text, {txt: text, in_tests: true})

    logger.verify
  end

  def test_tester_handle_text_partial_text
    logger = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: logger
    }
    tester = RokuBuilder::Tester.new(**device_config)

    text = "this\n***** STARTING TESTS *****\nis\na\ntest\n***** ENDING TESTS *****\nparagraph"

    logger.expect(:unknown, nil, ["is"])
    logger.expect(:unknown, nil, ["a"])
    logger.expect(:unknown, nil, ["test"])

    assert !tester.send(:handle_text, {txt: text, in_tests: false})

    logger.verify
  end
end
