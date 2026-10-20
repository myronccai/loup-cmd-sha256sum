# Design: sha256sum

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the arguments
into `Options`, handles `--help` and `--version`, and calls
`commands.sha256sum.run_sha256sum`. That function asks `sha256sum_report`
for a `Report`, the ordered list of everything to print and where it goes,
then prints it. Tests call `sha256sum_report` and the parsing and formatting
functions directly, so no output has to be captured.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (usage errors are status 1, as in GNU) |
| `source/cli/args.loup` | `Options`, `new_options`, `resolve_long` (unique prefixes), `validate` (GNU's invalid combinations), `parse_args` |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run the command, map exceptions to status 1 |
| `source/hash/sha256.loup` | `round_constants`, `initial_state`, `rotr`, `compress`, `padded_tail`, `digest`, `to_hex`, `hex_digest` |
| `source/commands/lines.loup` | `hash_line`, `escape_name`/`unescape_name`, `result_name`, `quote_name`, `cut_at_nul`, `parse_check_line` (`Entry`, `ParseState`) |
| `source/commands/sha256sum.loup` | `Report`, `input_problem`, `hash_files`, `check_list`, `sha256sum_report`, `run_sha256sum` |

## SHA-256

Loup's `uint32` throws on overflow, so words are kept in 64-bit `int`s and
masked with `& 0xFFFFFFFF` after every addition; `rotr` is
`((x >> n) | (x << (32 - n))) & MASK`, and `~e` is `e ^ MASK`. `digest`
reads whole blocks straight out of the input `bytes`, then builds the last
partial block, `0x80`, zeros and the 64-bit bit length in a `list[int]`
(`padded_tail`, one or two blocks). The message schedule `w` is one
64-element list reused for every block, passed as `edits`.

## Parsing

`parse_args` follows getopt_long: short options in groups (`-cw`), long
options exactly or by a unique prefix (`--stat`), no option takes an
argument (`--tag=1` is an error), operands collected in order, `--` ends the
options. `--help` and `--version` stop parsing at once, as in GNU.
`--status`, `--warn` and `--quiet` replace one another (the last wins).
`validate` then rejects GNU's invalid combinations in GNU's order.

## Check mode

`check_list` splits a list on `\n`, skips `#` comments and empty lines,
drops a trailing `\r`, and parses each line with `parse_check_line`, a port
of GNU's `split_3` and `bsd_split_3`: optional leading blanks and `\`
(escaped name), then either `SHA256 (NAME) = HASH` (the name runs to the
last `)`) or `HASH`, a blank, an optional ` `/`*`, and the name. Whether
single-blank `HASH NAME` lines are allowed is decided by the first line of
the run (`ParseState`). As in GNU, which reads lines as C strings, an
unescaped name ends at a NUL and an escaped one may not contain it. The
summary warnings, `--status`, `--quiet`, `--strict`, `-w` and
`--ignore-missing` follow GNU's `digest_check`.

## Native-build constraints

- A function that returns `bytes` crashes natively, so `input_digest` reads
  and hashes in one function and returns the hex string.
- Lists are read with `readText`, which keeps raw bytes natively, so names
  that are not valid UTF-8 match; `bytes.decode()` would turn them into
  U+FFFD.
- `Entry.valid` is not called `ok` because `Report` has an `ok` field, and
  native builds misread structs that cross modules when two structs share
  a field name at different positions.
- Every struct is built only in its defining module, through a factory
  (`new_options`, `new_state`, `new_report`).

## Differences from the original

- Each input is read whole before hashing (no streaming reads in Loup
  1.26.0), so memory grows with the file and an endless input never ends.
- An existing but unreadable file stops the native binary with the
  runtime's `IoError` message and status 1 (ROADMAP T1: no `stat()`; the
  native `IoError` is not catchable). Missing files and directories are
  checked with `exists` and `isDir` first and reported as GNU does.
- Names in messages are quoted as GNU does in a UTF-8 locale; invalid UTF-8
  bytes are not escaped as `$'\ooo'`.
- `-b`/`-t` only change the marker, as on any GNU/Linux system.
- Only SHA-256: no `--algorithm`/`--length` (GNU `cksum` options).
- `--version` prints one line, and `--help` is shorter.

## Error handling

Before reading, `input_problem` checks `exists` and `isDir`. A missing file
or directory in hash mode gives `sha256sum: NAME: ...` and status 1, and the
loop continues. In check mode the same message is followed by
`NAME: FAILED open or read` (unless `--status`), and a missing list gives
`sha256sum: LIST: No such file or directory`. Usage errors print the message
and the "Try" line, status 1. Any exception is mapped to status 1 in `run`.

## Testing

- `tests/sha256_test.loup`: NIST vectors, the 55/56/64/1000-byte boundaries,
  `rotr`, padding lengths, constants, `to_hex`.
- `tests/lines_test.loup`: output formats, escaping, quoting, NUL handling,
  GNU/BSD/escaped/bad/single-blank checksum lines.
- `tests/args_test.loup`: options, prefixes, ambiguity, replacement rules,
  `--`, usage errors and invalid combinations.
- `tests/sha256sum_test.loup`: whole runs on `tests/fixtures/` through
  `sha256sum_report` (stdout and stderr lines, success flag).
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary on files and standard input (including
  one million `a`s), every option, escaped and NUL-ended lists, messages and
  exit statuses, compared byte for byte.
