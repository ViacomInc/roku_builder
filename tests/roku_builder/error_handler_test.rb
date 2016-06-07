# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "test_helper.rb"

class RokuBuilder::ErrorHandler
  class << self
    def abort
      #do nothing
    end
  end
end

class ErrorHandlerTest < Minitest::Test
  def test_handle_error_codes
    error_groups = {
      fatal: {
        options_code: [
          RokuBuilder::EXTRA_COMMANDS,
          RokuBuilder::NO_COMMANDS,
          RokuBuilder::EXTRA_SOURCES,
          RokuBuilder::NO_SOURCE,
          RokuBuilder::BAD_CURRENT,
          RokuBuilder::BAD_IN_FILE
        ],
        configure_code:[
          RokuBuilder::CONFIG_OVERWRITE,
        ],
        device_code: [
          RokuBuilder::BAD_DEVICE,
          RokuBuilder::NO_DEVICES,
        ],
        load_code: [
          RokuBuilder::MISSING_CONFIG,
          RokuBuilder::INVALID_CONFIG,
          RokuBuilder::MISSING_MANIFEST,
          RokuBuilder::UNKNOWN_DEVICE,
          RokuBuilder::UNKNOWN_PROJECT,
          RokuBuilder::UNKNOWN_STAGE,
        ],
        command_code: [
          RokuBuilder::FAILED_SIDELOAD,
          RokuBuilder::FAILED_SIGNING,
          RokuBuilder::FAILED_DEEPLINKING,
          RokuBuilder::FAILED_NAVIGATING,
          RokuBuilder::FAILED_SCREENCAPTURE
        ]
      },
      info: {
        device_code: [
          RokuBuilder::CHANGED_DEVICE
        ],
        configure_code:[
          RokuBuilder::SUCCESS
        ]
      },
      warn: {
        load_code: [
          RokuBuilder::DEPRICATED_CONFIG
        ],
        options_code: [
          RokuBuilder::DEPRICATED
        ]
      }
    }
    error_groups.each_pair do |type,errors|
      errors.each_pair do |key,value|
        value.each do |code|
          logger = Minitest::Mock.new
          options = {logger: logger}
          options[:options] = {deeplink_depricated: true} if key == :load_code or key == :options_code
          options[key] = code
          logger.expect(type, nil)  {|string| string.class == String}
          method = "handle_#{key}s"
          RokuBuilder::ErrorHandler.send(method.to_sym, **options)
          logger.verify
        end
      end
    end
  end
end
