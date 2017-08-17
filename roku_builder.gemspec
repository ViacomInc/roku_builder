# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'roku_builder/version'

Gem::Specification.new do |spec|
  spec.name          = "roku_builder"
  spec.version       = RokuBuilder::VERSION
  spec.authors       = ["greeneca"]
  spec.email         = ["charles.greene@redspace.com"]
  spec.summary       = %q{Build Tool for Roku Apps}
  spec.description   = %q{Allows the user to easily sideload, package, deeplink, test, roku apps.}
  spec.homepage      = ""
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 2.3"

  spec.add_dependency "rubyzip",             "~> 1.2"
  spec.add_dependency "faraday",             "~> 0.12"
  spec.add_dependency "faraday-digestauth",  "~> 0.2"
  spec.add_dependency "git",                 "~> 1.3"
  spec.add_dependency "net-ping",            "~> 2.0"
  spec.add_dependency "net-telnet",          "~> 0.1"
  spec.add_dependency "oga",                 "~> 2.10"
  spec.add_dependency "win32-security",      "~> 0.5" # For windows compatibility

  spec.add_development_dependency "bundler",           "~> 1.7"
  spec.add_development_dependency "rake",              "~> 12.0"
  spec.add_development_dependency "byebug",            "~> 9.0"
  spec.add_development_dependency "minitest",          "~> 5.10"
  spec.add_development_dependency "minitest-autotest", "~> 1.0"
  spec.add_development_dependency "minitest-server",   "~> 1.0"
  spec.add_development_dependency "minitest-utils",    "~> 0.3"
  spec.add_development_dependency "webmock",           "~> 3.0"
  spec.add_development_dependency "simplecov",         "~> 0.12"
  spec.add_development_dependency "coveralls",         "~> 0.8"
  spec.add_development_dependency "yard",              "~> 0.9"
  spec.add_development_dependency "guard",             "~> 2.14"
  spec.add_development_dependency "guard-minitest",    "~> 2.4"
  spec.add_development_dependency "m",                 "~> 1.5"
end
