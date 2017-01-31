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
 * Profile Scene Graph applications

The tool allows scripting of the following:

 * Conroller inputs
 * Text Input
 * Screencaptures
 * Printing project information

Other tasks the tool can complete:

 * Device navigation
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

##### Top Level Configuration

 * devices: information for accessing devices
 * projects: this is a hash of project objects
 * keys: contains keys that will be used for signing packages
 * input_mapping: allows you to change key mappings for the intractive navigator

##### Device Configuration

 * devices.default: id of the default device
 * devices.<device_id>.ip: ip address of the device
 * devices.<device_id>.user: dev username for the roku device
 * devices.<device_id>.password: dev password for the roku device

##### Project Configuration

 * projects.default: the key for the default project
 * projects.parent_dir: optional directory path that all projects are relative
    to
 * projects.<project_id>.directory: full path of the git repository the houses
    the roku app
 * projects.<project_id>.app_name: Name used when packaging the app
 * projects.<project_id>.stage_method: Which method to use for switching app
    stages (git or script)
 * projects.<project_id>.stages: a hash of stage objects
 * projects.<project_id>.stages.<stage_id>.branch: name of the branch for the
    given stage (if stage_method = git). If using stage_method = stage then
    this can be removed.
 * projects.<project_id>.stages.<stage_id>.script: scripts to use to stage the
    app (if stage_method = script). If using stage_method = git this can be
    removed.
 * projects.<project_id>.stages.<stage_id>.script.stage: script run form the
    app root directory to stage app
 * projects.<project_id>.stages.<stage_id>.script -> unstage: script run form
    the app root directory to unstage app
 * projects.<project_id>.stages.<stage_id>.key: this can be a string referencing
    a key in the keys section or a hash of options
 * projects.<project_id>.stages.<stage_id>.key.keyed_pkg: path to a pkg file
    that has been signed
 * projects.<project_id>.stages.<stage_id>.key.password: password for the signed pkg

##### Key Configuration

 * keys.<key_id>.keyed_pkg: path to a pkg file that has been signed
 * keys.<key_id>.password: password for the signed pkg

The "input_mappings" section is optional but will allow you to override
the default input mappings. In the section each key is a key press code. The
value is a array with the desired command to run and a human readable key name.
To see the key press code for a specific key the --navigate command can be run
with the --debug option on to see a print out of all the keys pressed.

#### Basic steps for creating a Roku channel/application package

Official docs for packaging an application can be found [in the sdk](https://sdkdocs.roku.com/display/sdkdoc/Packaging+Your+Application), however the basic steps are:

1.  Side-load your application onto a Roku device for testing.
1.  Run the genkey utility to generate a key.  This key will sign packages. This step only needs to be done once.
1.  Run the package utility to generate the package.
1.  Download the package from the Roku device to your computer.

RokuBuilder makes running each of these steps easy, without needing to use the Roku device web interface or telnet.

#### Projects and Stages

The configuration for this gem allows you to define any number of project and
any number of stages for each project. It is intended that each app be defined
as a project and then the stages for that project would allow you to define
production/staging/etc. stages.

There are two different ways that stages can be defined. You can use a script
to define your stage. This gives you the greatest amount of freedom allowing
you to setup your stage anyway you want. The other option is to use git
staging. To do this you must have one branch for eash stage.

The project used in the examples below is a smart default. If you are in a
project directory then it will use that project. If you are not then it will
use the defualt that you have defined in your config. You can define what
project you want the command to be run on using the --project option:

    $ roku -lw --project project1

or:

    $ roku -lw -P project1

#### Commands and Sources

There are several commands that require a source option to run properly. These
include:

 * Sideload
 * Build
 * Package
 * Test
 * Key

There are several source options that can be supplied to these commands. Which
options you use will depend on the type of staging you are using and the app
you are trying to run the command. The options are as follows:

 * --ref or -r
   * This option only works with git type staging. It will allow you to run a
      command on a specific git branch, tag, or referance.
 * --stage or -s
   * This option will work with either git or script staging. It allows you to
      sideload a specific stage. If using script staging then it will run the
      configured stage script before sideloading and then run the unstage
      script after. If using git staging it will stach any local changes,
      switch to the configured branch, sideload, switch back to the previous
      branch, and unstach changes. This is the only source option that you can
      use when packaging.
 * --working or -w
   * This option will work with git or script staging. It will use the project
      configs to determine the directory to use but will not run any staging
      method.
 * --current or -c
   * This option will ignore any project configurattion and just us the entire
      current directory.
 * --in or -I
   * This option allows you to pass in a zip file of an already built app.


#### Sideloading

You can sideload an app directly to the device using this gem. The gem will
zip all of the configured files and upload it to the device and the remove the
zip. You can do so with the following commands:

    $ roku --sideload --stage production

or:

    $ roku -ls production

When sideoading you can use any of the source options approiate to your staging
method.

#### Building

You can build an app to be sideloaded later or by someone else by using the
following command:

    $ roku --build --working

or:

    $ roku -bw

When bulding you can use any of the source options approiate to your staging
method except the --in option.

#### Generating a key

Before you can package a channel, you must [generate a key](https://sdkdocs.roku.com/display/sdkdoc/Packaging+Your+Application#PackagingYourApplication-RunthegenkeyUtility)
that is used to sign the package. This key is used to sign a new package and is
also needed to sign a package when updating a channel.

You can create a key by running the genkey command:

    $ roku --genkey --debug

This will output the following data, all of which need to put in the `keys` section of `~/.roku_config.json`:

*  `Keyed PKG`: This is the signing key, used to sign new and updated packages
*  `Password`: Key's password
*  `DevID`: The developer ID associated with the key.  Don't need to save this, but it is best practice to include this string in the signing keys filename

#### Packaging

To package an app you need to have at least on stage set up in your
configuration file that has a key. Once you have that setup then you can run
the following:

    $ roku --package --stage production

or:

    $ roku -ps production

The package command will automatically [Rekey](https://github.com/rokudev/docs/blob/master/develop/guides/packaging.md#rekeying)
your roku device before packaging the channel

#### Monitoring Logs

The tool has the ability to monitor the different development logs. You use
the feature using the command --monitor and passing in the type of log you want
to monitor. For example the following command will monitor the main
brightscript log:

    $ roku --monitor main

or:
    $ roku -m main

or

    $ roku --monitor

The following are the options to be passed in as type:

 * main
 * sg (depricated)
 * task1 (depricated)
 * task2 (depricated)
 * task3 (depricated)
 * taskX (depricated)
 * profile

If no option is passed in then main log is monitored.

The tool connects to the roku via telnet and prints everything that it
recieves. It will continue indefinatly unless it is stopped via Ctrl-c or
entering "q".

The monitor tool also includes command history and some tab completeion.

#### Interactive Navigation

The gem has the ability to capture keyboard input and send it to the roku as
remote inputs. This can be done by running the following command:

    $ roku --navigate

Running in verbose mode will print out all of the key mappings avaiable. If you
want to change these mappings you can do so via the input_mapping config values
. To determine the codes needed to enter in the input_mapping config you can
run the navigator in debug mode.

#### Profiling Scene Graph

The tool will help a little with profiling scenegraph applications. Running the
following command will print a list of all of the currently created nodes
types and how many of each are being created.

    $ roku --profile stats

If you want to see more information about each node you can monitor the
profile log (See Monitoring Logs above) and enter the following command:

    $ sgnodes all

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

    $ roku --nav <command>

The possible commands are as follows:

 * up
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

You can delete the currently sideloaded app using the following command:

    $ roku --delete

You can use a differnt configuration file useing the following option:

    $ roku --delete --config <path>

This path will be expanded so you do not have to use the full path

## Devices

In the examples above the device used is a smart default. It will use the
default device defined in the configuration file. If that device is not online
it will look start at the top and try each device until it findes an avaiable
device. If you have multiple devices defined in your config then you can select
a different one using the following option:

    $ roku -lw --device device2

or:

    $ roku -lw -D device2


## Documentation

To generate the documentation run the following command in the project root
directory:

    $ yard doc --protected lib


## Improvements

 * Allow start and end delimiter for tests to be configured
 * Fix file naming when building from a referance
 * Extend profiling

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## License

On June 1st, 2016, we switched this project from the MIT License to Apache 2.0
