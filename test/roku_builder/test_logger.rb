# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

module RokuBuilder
  class LoggerTest < Minitest::Test

    def test_logger
      Logger.class_variable_set(:@@instance, nil)
      logger_a = Logger.instance
      logger_b = Logger.instance
      assert_equal logger_a, logger_b
    end

    def test_set_debug
      logger = Minitest::Mock.new
      Logger.class_variable_set(:@@instance, logger)
      logger.expect(:level=, nil, [::Logger::DEBUG])
      Logger.set_debug
      logger.verify
      Logger.set_testing
    end

    def test_set_info
      logger = Minitest::Mock.new
      Logger.class_variable_set(:@@instance, logger)
      logger.expect(:level=, nil, [::Logger::INFO])
      Logger.set_info
      logger.verify
      Logger.set_testing
    end

    def test_set_warn
      logger = Minitest::Mock.new
      Logger.class_variable_set(:@@instance, logger)
      logger.expect(:level=, nil, [::Logger::WARN])
      Logger.set_warn
      logger.verify
      Logger.set_testing
    end

    def test_logger_testing
      Logger.set_testing
      logger = Logger.instance
      assert_nil logger.instance_variable_get(:@logdev).instance_variable_get(:@filename)
    end
  end
end
