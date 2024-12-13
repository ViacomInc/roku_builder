Static Channel Analysis
=======================

Performs BrightScript code static analysis. Provides info about debug code present, deprecated usage etc. Checks
manifest file for proper attributes.

Requires Java to be installed in the system.

Tool usage from command line
----------------------------

Usage:

`java -jar PATH_TO_JAR PATH_TO_PROJECT_OR_ZIP`

Examples:

- `java -jar sca-cmd.jar my_project`
- `java -jar sca-cmd.jar my_project.zip`

**Severity level choice:**

You can specify verbosity level using `--severity` command line parameter. This parameter is optional. It is possible to
use short version `-s` instead of `--severity`.

Usage:

`java -jar PATH_TO_JAR PATH_TO_PROJECT_OR_ZIP --severity SEVERITY_LEVEL`

Example:

`java -jar sca-cmd.jar my_project --severity info`

Available `SEVERITY_LEVEL` values are: `info`, `warning` and `error`:

- `info` - print all the logs
- `warning` - print warnings and errors
- `error` - print errors only

If severity level is not specified `warning` is used.

**Category filter:**

You can filter output logs by categories using `--filter-categories` command line parameter. Short version is `-c`. This
parameter is optional.

Usage:

`java -jar PATH_TO_JAR PATH_TO_PROJECT_OR_ZIP --filter-categories COMMA_SEPARATED_CATEGORIES`

Example:

`java -jar sca-cmd.jar my_project --filter-categories deprecated_components,manifest,package`

List of categories:

- `uncategorized`
- `deprecated_components`
- `deprecated_apis`
- `manifest`
- `raf`
- `package`
- `red`
- `deep_linking`
- `performance`
- `billing`
- `channel_store`

If categories are not specified output logs are not filtered.

**Exit with status code 1:**

You can specify verbosity level on which program should exit with status code `1` using `--exit` command line parameter.
This parameter is optional. It is possible to use short version `-e` instead of `--exit`.

Usage:

`java -jar PATH_TO_JAR PATH_TO_PROJECT_OR_ZIP --exit COMMA_SEPARATED_SEVERITY_LEVELS`

Example:

`java -jar sca-cmd.jar my_project --exit error,warning`

Available `SEVERITY_LEVEL` values are: `info`, `warning` and `error`:

If specified severity levels are present in the response, program will exit with status code `1`, otherwise with status
code `0`.

If exit severity levels are not specified the program exits with status code `0`.

**Output format choice:**

You can generate local report file by specifying file path in `--output` and file format in `--format` command line
parameters. Destination folder for report file should be already created in your file system. It is possible to use
short versions `-o` and `-f` instead of `--output` and `--format` accordingly.

Usage:

`java -jar PATH_TO_JAR PATH_TO_PROJECT_OR_ZIP --output PATH_TO_REPORT_FILE --format COMMA_SEPARATED_FORMATS`

Example:

`java -jar sca-cmd.jar my_project --output "../reports/report.xml" --format console,junit`

Supported format values are: `console` and `junit`:

- `console` - print all outputs to console
- `json` - save all outputs to specified json file
- `junit` - save all outputs to specified JUnit xml file

If format is not specified `console` is used. If specified any file format but not specified output file path a default
file path value is used. For `junit`, this is `reports/SCA_Report.xml`. For `json`, this is `reports/SCA_Report.json`

**Usage without manual java invocation:**

Archive structure:

```
.
└── sca-cmd
    ├── bin
    │   ├── sca-cmd
    │   └── sca-cmd.bat
    └── lib
        └── sca-cmd.jar
```

Usage examples:

- Mac/Linux/UNIX: `./sca-cmd PATH_TO_PROJECT_OR_ZIP`
- Windows: `sca-cmd.bat PATH_TO_PROJECT_OR_ZIP`

You must be in the `bin` folder to use this command. `sca-cmd` is just `sh` script inside, it can be used in Unix-like
systems. `sca-cmd.bat` is for Windows systems. Each script takes the same command line arguments as `sca-cmd.jar`.
Actually, it just invokes `sca-cmd.jar` from the `lib` folder with passed arguments.

**EXE usage on Windows:**

EXE usage is the same as for `bat` file. It also takes the same arguments.

Example: `sca-cmd.exe PATH_TO_PROJECT_OR_ZIP`
