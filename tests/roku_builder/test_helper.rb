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


def good_config
  {
    devices: {
      default: :roku,
      roku: {
        ip: "192.168.0.100",
        user: "user",
        password: "password"
      }
    },
    projects: {
      default: :project1,
      project1: {
        directory: "/dev/null",
        folders: ["resources","source"],
        files: ["manifest"],
        app_name: "<app name>",
        stage_method: :git,
        stages:{
          production: {
            branch: "production",
            key: {
              keyed_pkg: "/dev/null",
              password: "<password for pkg>"
            }
          }
        }
      },
      project2: {
        directory: "/dev/nuller",
        folders: ["resources","source"],
        files: ["manifest"],
        app_name: "<app name>",
        stage_method: :git,
        stages:{
          production: {
            branch: "production",
            key: {
              keyed_pkg: "/dev/null",
              password: "<password for pkg>"
            }
          }
        }
      }
    }
  }
end
