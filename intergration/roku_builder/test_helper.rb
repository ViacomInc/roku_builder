# ********** Copyright Viacom, Inc. Apache 2.0 **********

require "simplecov"
require "coveralls"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter::new([
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
])
SimpleCov.start

require "byebug"
require "roku_builder"
require "minitest/autorun"
require "minitest/utils"
require "securerandom"

ROKU_IP = "192.168.11.114"

module Minitest
  module Assertions
    def wait_assert(timeout = 10, msg = nil)
      self.assertions += 1
      start = Time.now
      result = nil
      while (Time.now - start) < timeout
        result = yield
        return true if result
      end
      msg ||= "Expected #{result} to be truthy"
      raise Minitest::Assertion, msg
    end
    def assert_log(log, timeout = 10, msg = nil)
      self.assertions += 1
      ip = good_config(self.class)[:devices][:roku][:ip]
      telnet_config = {
        'Host' => ip,
        'Port' => 8085
      }
      waitfor_config = {
        'Match' => /#{log}/,
        'Timeout' => timeout
      }
      connection = Net::Telnet.new(telnet_config)
      begin
        connection.waitfor(waitfor_config) do |txt|
          #puts txt
        end
      rescue Timeout::Error
        msg ||= "Expected to see log with #{log}"
        raise Minitest::Assertion, msg
      end
      sleep 1
      true
    end
  end
end

module Helpers
  def roku(config=nil)
    config ||= @config
    "bin/roku --config #{config}"
  end

  def testfiles_path(klass)
    klass = klass.to_s.split("::")[1].underscore
    File.join(File.dirname(__FILE__), "test_files", klass)
  end

  def build_config(klass, target=nil, config=nil)
    target = "config.json" unless target
    config_path = File.join(testfiles_path(klass), target)
    config = good_config(klass) unless config
    config_string = JSON.pretty_generate(config)
    file = File.open(config_path, "w")
    file.write(config_string)
    file.close
    config_path
  end


  def build_uuid_script
    script = [
      "function uuid()\n",
      " return \"#{@uuid}\"\n",
      "end function"
    ]
    path = File.join(testfiles_path(self.class), "components", "uuid.brs")
    FileUtils.rm (path) if File.exist?(path)
    File.open(path, "w") do |io|
      script.each do |line|
        io.write(line)
      end
    end
  end

  def cleanup_uuid_script
    path = File.join(testfiles_path(self.class), "components", "uuid.brs")
    FileUtils.rm (path) if File.exist?(path)
  end

  def good_config(klass)
    root_dir = testfiles_path(klass)
    {
      devices: {
      default: :roku,
      roku: {
      ip: ROKU_IP,
      user: "rokudev",
      password: "aaaa"
    }
    },
      projects: {
      default: :project1,
      project1: {
      directory: root_dir,
      source_files: ["images","source","components", "manifest","file.tmp"],
      app_name: "App Name",
      stage_method: :script,
      stages:{
      production: {
      script: {stage: "touch file.tmp", unstage: "rm file.tmp"},
      key: "a"
    }
    }
    }
    },
      keys: {
      a: {
      keyed_pkg: File.join(root_dir, "test.pkg"),
      password: "CvOqcutO3X419INdUbOyqw=="
    }
    },
      input_mappings: {
      "a": ["home", "Home"]
    }
    }
  end
end
