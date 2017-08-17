# RokuBuilder

[![Gem Version](https://badge.fury.io/rb/roku_builder.svg)](https://badge.fury.io/rb/roku_builder)
[![Dependency Status](https://gemnasium.com/ViacomInc/roku_builder.svg)](https://gemnasium.com/ViacomInc/roku_builder)
[![Build Status](https://travis-ci.org/ViacomInc/roku_builder.svg?branch=master)](https://travis-ci.org/ViacomInc/roku_builder)
[![Coverage Status](https://coveralls.io/repos/github/ViacomInc/roku_builder/badge.svg?branch=master)](https://coveralls.io/github/ViacomInc/roku_builder?branch=master)
[![Code Climate](https://codeclimate.com/github/ViacomInc/roku_builder/badges/gpa.svg)](https://codeclimate.com/github/ViacomInc/roku_builder)

A tool to help with Roku Development. Assists with many development/deployment
tasks. More information can be found in the [wiki](https://github.com/ViacomInc/roku_builder/wiki).

## Installation

Install it yourself with:

    $ gem install roku_builder

## Quick Start Guide

### Sideloading

To sideload example or tutoral, switch to correct directory and run:

    $ roku -lc

To sideload project, ensure [config](https://github.com/ViacomInc/roku_builder/wiki/Configuration#project-configuration) is setup and run:

    $ roku -lw

or

    $ roku -ls <stage>

### Debugging

To monitor debug log and interact with debugger run:

    $ roku -m

### Packaging

To package and app:

  1. Generate a key (Once):

    $ roku --genkey

  1. Add key to (config)[https://github.com/ViacomInc/roku_builder/wiki/Configuration#key-configuration] (Once).
  1. Package channel:

    $ roku -ps <stage>

## Documentation

To generate the documentation run the following command in the project root
directory:

    $ yard doc --protected lib


## Improvements

 * Fix file naming when building from a referance
 * Add configuration option for build_version format

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## License

On June 1st, 2016, we switched this project from the MIT License to Apache 2.0
