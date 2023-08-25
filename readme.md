
## SVN `access` file Utility

CLI tool (`svn-access`) to read, filter/search, and sort SVN access files.

### Build/Run Prerequisites

  Required: JS interpreter [https://github.com/stfwi/duktape-cc](https://github.com/stfwi/duktape-cc).
  Optional: GNU make (version >=4.1) to build self-contained executable.

### Script/application usage:

  ```
    Usage: svn-access [options] <command> <file> [args...]

      SVN access file analysis and sanitizing utility.

    Options:

    --json           Output JSON format with pretty-print.
    --json-inline    Output JSON format without pretty-printing.
    --no-comments    Ignore comments while parsing a file.

    Commands:

    - read <file>
                Reads a file, prints a JSON representation to stdout.

    - sections <file>
                Lists all section names in a file.

    - sort <file>
                Prints all sections in a file, sorted by section name
                and length. [groups] is always listed first.

    - groups <file> [search [terms]]
                Lists all groups in a file (or all containing at least
                one of the search terms, case insensitive).

    - group <file> <match1> [match2 [...]]
                Prints all sections in a file, which contain at least
                one of the group names to match (case insensitive).

    - user <file> <match1> [match2 [...]]
                Prints all sections in a file, which contain at least
                one of the user names to match (case insensitive).
                Only entries with matches are shown, also non-matching
                users are removed from groups.
  ```

### Known issues

  - If the SVN access file contains invalid character set (no ascii,
    and no utf8), the application will exit with an error. That is
    intentional, *but the line/column is not shown yet*.
