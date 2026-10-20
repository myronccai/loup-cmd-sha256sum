# Requirements: sha256sum

## Introduction

`sha256sum` prints the SHA-256 digest of files or standard input, and checks
files against a list of digests that it printed earlier. This repository
recreates GNU coreutils `sha256sum` in Loup, with the hash written in pure
Loup because the Lite edition has no crypto library (ROADMAP T3). It is the
twentieth Linux command in the loup-cmd series.

## Requirements

### Requirement 1: Digests

**User Story:** As a shell user, I want the SHA-256 digest of a file so that
I can identify its contents or compare it with a published checksum.

#### Acceptance Criteria

1. THE program SHALL compute SHA-256 as FIPS 180-4 defines it, giving the
   NIST known answers (`""`, `abc`, the 448- and 896-bit messages and one
   million `a`s) and correct results at every block and padding boundary.
2. WHEN files are given, THE program SHALL print one line per file:
   64 lower-case hex digits, a space, a mode character (` ` for text, `*`
   with `-b`) and the name, ended by a newline.
3. WHEN no file is given, or a file is `-`, THE program SHALL read standard
   input and name it `-`; standard input read a second time is empty.
4. THE program SHALL hash every byte of the input, binary data included.

### Requirement 2: Output formats

**User Story:** As a script author, I want GNU's output formats so that the
lists work with other tools.

#### Acceptance Criteria

1. WHEN `--tag` is given, THE program SHALL print `SHA256 (NAME) = HASH`.
2. WHEN a name holds a backslash or a newline, THE program SHALL write it
   with `\\` and `\n` after a leading backslash on the line.
3. WHEN `-z` is given, THE program SHALL end lines with NUL and write names
   unescaped.
4. WHEN `--tag` and `--text` are both given, THE program SHALL reject the
   command line.

### Requirement 3: Checking lists

**User Story:** As a shell user, I want to check files against a checksum
list so that I know which ones changed.

#### Acceptance Criteria

1. WHEN `-c` is given, THE program SHALL read each FILE as a checksum list in
   GNU (`HASH  NAME`, `HASH *NAME`, `HASH NAME` when the list starts that
   way) or BSD (`SHA256 (NAME) = HASH`) format, with escaped names, CRLF
   line ends, upper-case hex, empty lines and `#` comments.
2. THE program SHALL print `NAME: OK`, `NAME: FAILED` or
   `NAME: FAILED open or read` for each listed file, and then on standard
   error the counts of improperly formatted lines, unreadable files and
   mismatches as GNU words them.
3. WHEN a list has no valid line, THE program SHALL print
   `sha256sum: LIST: no properly formatted checksum lines found`.
4. WHEN `--quiet` is given, THE program SHALL omit `OK` lines; WHEN
   `--status` is given, SHALL print no results or warnings; WHEN `-w` is
   given, SHALL report each bad line with its number; WHEN `--strict` is
   given, SHALL fail on bad lines; WHEN `--ignore-missing` is given, SHALL
   skip missing files and report a list that verified nothing.
5. THE program SHALL exit with status 0 only when every list had a valid
   line and every listed file was read and matched.

### Requirement 4: Command line and errors

**User Story:** As a shell user, I want GNU's option syntax and messages so
that sha256sum fits into existing scripts.

#### Acceptance Criteria

1. THE program SHALL accept combined short options, options after file
   names, `--`, and long options abbreviated to a unique prefix.
2. WHEN an option is unknown, ambiguous, given an argument, or combined in a
   way GNU rejects (check-only options without `-c`, `-c` with `--tag`,
   `-z`, `-b` or `-t`), THE program SHALL print GNU's message and
   `Try 'sha256sum --help' for more information.` and exit with status 1.
3. WHEN a file does not exist or is a directory, THE program SHALL print
   `sha256sum: NAME: No such file or directory` (or `Is a directory`), with
   the name quoted as GNU does, continue with the other files and exit with
   status 1.
4. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or `sha256sum (loup-cmd-sha256sum) 0.1.0` and exit with status 0.
