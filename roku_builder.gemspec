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

  spec.required_ruby_version = "~> 3.0"

  spec.add_dependency "rubyzip",             "~> 1.2"
  spec.add_dependency "faraday",             "~> 2.3"
  spec.add_dependency "faraday-multipart",   "~> 1.0"
  spec.add_dependency "faraday-digestauth",  "~> 0.2"
  spec.add_dependency "git",                 "~> 1.3"
  spec.add_dependency "net-ping",            "~> 2.0"
  spec.add_dependency "net-telnet",          "~> 0.1"
  spec.add_dependency "nokogiri",            "~> 1.12"
  spec.add_dependency "win32-security",      "~> 0.5" # For windows compatibility
  spec.add_dependency "image_size",          "~> 2.0"
  spec.add_dependency "jwt",                 "~> 2.7"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-autotest"
  spec.add_development_dependency "minitest-server"
  spec.add_development_dependency "minitest-utils"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-minitest"
  spec.add_development_dependency "m"
end
