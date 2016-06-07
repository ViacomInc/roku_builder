# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class UtilTest < Minitest::Test
  def test_util_init
    device_config = {
      ip: "111.222.333",
      user: "user",
      password: "password",
      logger: Logger.new("/dev/null")
    }
    test = TestClass.new(**device_config)
    assert test.inited
  end
end

class TestClass < RokuBuilder::Util
  def init
    @inited = true
  end
  def inited
    @inited || false
  end
end
