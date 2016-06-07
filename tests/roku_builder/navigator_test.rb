# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class NavigatorTest < Minitest::Test
  def test_navigator_nav
    commands = {
      up: "Up",
      down: "Down",
      right: "Right",
      left: "Left",
      select: "Select",
      back: "Back",
      home: "Home",
      rew: "Rev",
      ff: "Fwd",
      play: "Play",
      replay: "InstantReplay"
    }
    commands.each {|k,v|
      path = "/keypress/#{v}"
      navigator_test(path: path, input: k, type: :nav)
    }
  end

  def test_navigator_nav_fail
    path = ""
    navigator_test(path: path, input: :bad, type: :nav, success: false)
  end

  def test_navigator_type
    path = "keypress/LIT_"
    navigator_test(path: path, input: "Type", type: :text)
  end

  def navigator_test(path:, input:, type:, success: true)
    connection = Minitest::Mock.new
    faraday = Minitest::Mock.new
    io = Minitest::Mock.new
    response = Minitest::Mock.new

    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    if success
      if type == :nav
        connection.expect(:post, response, [path])
        response.expect(:success?, true)
      elsif type == :text
        input.split(//).each do |c|
          path = "/keypress/LIT_#{CGI::escape(c)}"
          connection.expect(:post, response, [path])
          response.expect(:success?, true)
        end
      end
      faraday.expect(:headers, {})
      faraday.expect(:request, nil, [:digest, device_config[:user], device_config[:password]])
      faraday.expect(:request, nil, [:multipart])
      faraday.expect(:request, nil, [:url_encoded])
      faraday.expect(:adapter, nil, [Faraday.default_adapter])
    end if

    navigator = RokuBuilder::Navigator.new(**device_config)
    result = nil
    Faraday.stub(:new, connection, faraday) do
      if type == :nav
        result = navigator.nav(command: input)
      elsif type == :text
         result = navigator.type(text: input)
      end
    end

    assert_equal success, result

    connection.verify
    faraday.verify
    io.verify
    response.verify
  end

  def test_navigator_screen
    logger = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: logger
    }
    navigator = RokuBuilder::Navigator.new(**device_config)

    logger.expect(:unknown, nil, ["Home x 5, Fwd x 3, Rev x 2,"])
    logger.expect(:unknown, nil, ["Home x 5, Up, Rev x 2, Fwd x 2,"])

    navigator.screen(type: :secret)
    navigator.screen(type: :reboot)

    logger.verify
  end

  def test_navigator_screen_fail
    logger = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: logger
    }
    navigator = RokuBuilder::Navigator.new(**device_config)

    assert !navigator.screen(type: :bad)

    logger.verify
  end

  def test_navigator_screens
    logger = Minitest::Mock.new
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: logger
    }
    navigator = RokuBuilder::Navigator.new(**device_config)

    navigator.instance_variable_get("@screens").each_key do |key|
      logger.expect(:unknown, nil, [key])
    end

    navigator.screens

    logger.verify
  end
end
