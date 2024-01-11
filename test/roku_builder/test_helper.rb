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
require "webmock/minitest"


RokuBuilder.set_testing
WebMock.disable_net_connect!
def register_plugins(plugin_class)
  RokuBuilder.class_variable_set(:@@dev, false)
  plugins = [plugin_class]
  plugins.each do |plugin|
    plugins.concat(plugin.dependencies)
    unless RokuBuilder.plugins.include?(plugin)
      RokuBuilder.register_plugin(plugin)
    end
  end
end
def clean_device_locks(names=["roku"])
  names.each do |device|
    path = File.join(Dir.tmpdir, device)
    File.delete(path) if File.exist?(path)
  end
end
def build_config_options_objects(klass, options = {validate: true}, empty_plugins = true, config_hash = nil)
  options = build_options(options, empty_plugins)
  config = RokuBuilder::Config.new(options: options)
  if config_hash
    config.instance_variable_set(:@config, config_hash)
  else
    config.instance_variable_set(:@config, good_config(klass))
  end
  config.parse
  [config, options]
end

def build_config_object(klass, options= {validate: true}, empty_plugins = true)
  build_config_options_objects(klass, options, empty_plugins).first
end

def test_files_path(klass)
  klass = klass.to_s.split("::")[1].underscore
  File.join(File.dirname(__FILE__), "test_files", klass)
end

def build_options(options = {validate: true}, empty_plugins = true)
  if empty_plugins
    RokuBuilder.class_variable_set(:@@plugins, [])
    RokuBuilder.class_variable_set(:@@dev, false)
    require "roku_builder/plugins/core"
    RokuBuilder.register_plugin(RokuBuilder::Core)
  end
  options = RokuBuilder::Options.new(options: options)
  options.validate
  options
end

def tmp_folder()
  Dir.tmpdir()
end

def is_uuid?(uuid)
  uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
  return true if uuid_regex.match?(uuid.to_s.downcase)
  false
end

def good_config(klass=nil)
  root_dir = "/tmp"
  root_dir = test_files_path(klass) if klass
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
        directory: root_dir,
        source_files: ["manifest", "images", "source"],
        app_name: "<app name>",
        stage_method: :git,
        stages:{
          production: {
            branch: "production",
            key: {
              keyed_pkg: File.join(root_dir, "test.pkg"),
              password: "password"
            }
          }
        }
      },
      project2: {
        directory: root_dir,
        source_files: ["images","source","manifest"],
        app_name: "<app name>",
        stage_method: :script,
        stages:{
          production: {
            script: {stage: "stage_script", unstage: "unstage_script"},
            key: "a"
          }
        }
      }
    },
    keys: {
      a: {
        keyed_pkg: File.join(root_dir, "test.pkg"),
        password: "password"
      }
    },
    input_mappings: {
      "a": ["home", "Home"]
    },
    api_keys: {
      key1: File.join(root_dir, "test_key.json")
    }
  }
end
