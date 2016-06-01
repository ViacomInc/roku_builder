# RokuBuilder

[![Gem Version](https://badge.fury.io/rb/roku_builder.svg)](https://badge.fury.io/rb/roku_builder)
[![Dependency Status](https://gemnasium.com/ViacomInc/roku_builder.svg)](https://gemnasium.com/ViacomInc/roku_builder)
[![Build Status](https://travis-ci.org/ViacomInc/roku_builder.svg?branch=master)](https://travis-ci.org/ViacomInc/roku_builder)
[![Coverage Status](https://coveralls.io/repos/github/ViacomInc/roku_builder/badge.svg?branch=master)](https://coveralls.io/github/ViacomInc/roku_builder?branch=master)
[![Code Climate](https://codeclimate.com/github/ViacomInc/roku_builder/badges/gpa.svg)](https://codeclimate.com/github/ViacomInc/roku_builder)

A tool to help with Roku Development. Assists with the following roku
development tasks:

 * Sideloading
 * Packaging
 * Building
 * Testing
   * Deeplink testing
   * Intergration test scripting
 * Manifest Updating
 * App Deleteing
 * Package Inspection
 * Monitoring logs

The tool allows scripting of the following interactions with the roku:

 * Conroller inputs
 * Text Input
 * Screencaptures

Other tasks the tool can complete:

 * Configuration Generation
 * Configuration Validation
 * Configuration Updating


## Installation

Install it yourself with:

    $ gem install roku_builder

## Usage

#### Configuration

The gem must have a configuration file. To generate this file you can run the
following command:

    $ roku --configure

This will create the file '~/.roku_config.json' with a default configuration.
Edit this file to add appropriate values. The following are default
configuration options:

 * devices: information for accessing devices
 * devices -> default: id of the default device
 * projects: this is a hash of project objects
 * projects -> default: the key for the default project

 Each Device has the following options:

 * ip: ip address of the device
 * user: dev username for the roku device
 * password: dev password for the roku device

 Each project has the following options:

 * directory: full path of the git repository the houses the roku app
 * app_name: Name used when packaging the app
 * stage_method: Which method to use for switching app stages (git or script)
 * stages: a hash of stage objects

 Each stage has the following options:

 * branch: name of the branch for the given stage (if stage_method = git)
 * script: scripts to use to stage the app (if stage_method = script)
 * script -> stage: script run form the app root directory to stage app
 * script -> unstage: script run form the app root directory to unstage app
 * key: has of key options for signing a package
 * key -> keyed_pkg: path to a pkg file that has been signed
 * key -> password: password for the signed pkg


#### Sideloading

There are several ways to side load an app. You can sideload based on a stage,
an arbitrary git referance or the working directory.

To sideload a stage you can run the following command:

    $ roku --sideload --stage production

This will sideload the production stage. By default the production stage is
used. So the above is equivalent to the following:

    $ roku --sideload

and:

    $ roku -l

To sideload via a git referance you can run the following command

    $ roku --sideload --ref master

This will sideload the master branch. The following is equivalent:

    $ roku -lr master

To sideload the current working directory you can run the following:

    $ roku --sideload --working

or:

    $ roku -lw

If you choose to sideload via stage or git referance then the roku tool with
stash any changes in the working directory and then apply the stash after. From
time to time there may be an issue with this and you will have to clear the
stash manually.

You can also sideload the current directory even if it is not setup as a
project. If the directory has a manifest file then you can run the following
command:

    $ roku --sideload --current

or:

    $ roku -lc

#### Packaging

To package an app you need to have at least on stage set up in your
configuration file that has a key. Once you have that setup then you can run
the following:

    $ roku --package --stage production

or:

    $ roku -ps production

#### Building

You can build an app to be sideloaded later or by someone else by using the
following command:

    $ roku --build --stage production

or:

    $ roku -bw


#### Monitoring Logs

The tool has the ability to monitor the different development logs. You use
the feature using the command --monitor and passing in the type of log you want
to monitor. For example the following command will monitor the main
brightscript log:

    $ roku --monitor main

or:
    $ roku -m main

The following are the options to be passed in as type:

 * main
 * sg
 * task1
 * task2
 * task3
 * taskX

The tool connects to the roku via telnet and prints everything that it
recieves. It will continue indefinatly unless it is stopped via Ctrl-c or
entering "q".

#### Testing

There are a few tools that can be used for testing. The testing command will
sideload the branch defined in the testing stage. It will then connect to the
device via telnet and look for the following strings and prints everything
inbetween them:

Start delimiter: \*\*\*\*\* STARTING TESTS \*\*\*\*\*

End delimiter: \*\*\*\*\* ENDING TESTS \*\*\*\*\*

This is designed to be used with the brstest library. Ensure that if you use
this that the app the prints out a sufficent number of lines after the tests
are run otherwise it will just grab the test run from last time.

Another tool for testing is the navigate command. You can use this to script
navigation on the roku console. The command is used as follows:

    $ roku --navigate <command>

The possible commands are as follows:

https://github.com/ViacomInc/roku_builde * up
 * down
 * right
 * left
 * select
 * back
 * home
 * rew
 * ff
 * play
 * replay

There is also a command that will allow you to send text to the roku. It is
used as follows:

    $ roku --type <text>

#### Other Tools

You can deeplink into your app using the following command:

    $ roku --deeplink-options "a:b c:d"

or

    $ roku -o "a:b c:d"

This will deeplink into the app sending the keypair values as defined in the
string. You can also have the app sideloaded first by adding one of the
source options (--working/-w, --current/-c, --ref/-r, or --stage/-s).

You can restart the roku device using the following command:

    $ roku --restart

You can delete the currently sideloaded app using the following command:

    $ roku --delete

You can use a differnt configuration file useing the following option:

    & roku --delete --config <path>

This path will be expanded so you do not have to use the full path

## Projects

The project used in the above examples is a smart default. If you are in a
project directory then it will use that project. If you are not then it will
use the defualt that you have defined in your config. You can define what
project you want the command to be run on using the --project option:

    $ roku -lw --project project1

or:

    $ roku -lw -P project1

## Stages

Each project can have any number of stages. stages can be defined in a number
of ways. The default is to use git branches to define stages. You can setup a
branch for each stage and the gem will automatically switch between them as
needed. If using git stages then the gem will ensure to stash any change you
currently have before checking out the required branch. When done it will
switch back and unstash the changes. You can use the -w or --working options
to avoid this.

The other method of staging is script staging. This will run a script you
define before and after performing any actions. This will let you stage your
app anyway you like as long as it can be done via script.

## Devices

In the examples above the default device is used. If you have multiple devices
defined in your config then you can select a different one using the following
option:

    $ roku -lw --device device2

or:

    $ roku -lw -D device2


## Documentation

To generate the documentation run the following command in the project root
directory:

    $ yard doc --protected lib


## Improvements

 * Don't require a device for non device tasks
 * Account for missing folders or files
 * Increase testing
   * Config Unit Tests
   * Intergration Tests
 * Move RokuBuilder::Controller to RokuBuilder?
 * Allow start and end delimiter for tests to be configured
 * Fix fgile naming when building from a referance

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## License

On June 1st, 2016, we switched this project from the MIT License to Apache 2.0