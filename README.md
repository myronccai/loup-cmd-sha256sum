# loup-cmd-sha256sum

GNU `sha256sum` recreated in [Loup](https://code-craft.ai/references/loup):
print or check SHA-256 checksums, with SHA-256 itself written in pure Loup
and tested against the NIST known answers.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                            # native binary: build/sha256sum
make ci                               # check, unit tests, build, end-to-end tests
make run ARGS="--tag package.lppkg"   # run from source with loup run
```

```text
$ build/sha256sum notes.txt abc.txt
d9014c4624844aa5bac314773d6b689ad467fa4e1d1a50a1b8a99d5a95f72ff5  notes.txt
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  abc.txt
$ printf abc | build/sha256sum
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -
$ build/sha256sum --tag abc.txt
SHA256 (abc.txt) = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
$ build/sha256sum notes.txt abc.txt > SHA256SUMS
$ build/sha256sum -c SHA256SUMS
notes.txt: OK
abc.txt: OK
$ printf "changed\n" > abc.txt
$ build/sha256sum -c SHA256SUMS; echo "exit $?"
notes.txt: OK
abc.txt: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
exit 1
$ build/sha256sum -c --quiet SHA256SUMS
abc.txt: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
$ build/sha256sum -c --status SHA256SUMS; echo "exit $?"
exit 1
$ build/sha256sum missing.txt; echo "exit $?"
sha256sum: missing.txt: No such file or directory
exit 1
$ build/sha256sum --tag --text abc.txt; echo "exit $?"
sha256sum: --tag does not support --text mode
Try 'sha256sum --help' for more information.
exit 1
$ build/sha256sum --version
sha256sum (loup-cmd-sha256sum) 0.1.0
```

With no FILE, or when FILE is `-`, sha256sum reads standard input.

| Option | Meaning |
|---|---|
| `-b`, `--binary` | mark the file as read in binary mode (`*` before the name) |
| `-t`, `--text` | text mode (the default; same digest on Linux) |
| `--tag` | BSD-style lines: `SHA256 (NAME) = HASH` |
| `-z`, `--zero` | end each output line with NUL instead of newline, and do not escape names |
| `-c`, `--check` | read checksum lists from the FILEs and check each listed file |
| `--ignore-missing` | with `-c`: skip listed files that do not exist |
| `--quiet` | with `-c`: do not print `OK` lines |
| `--status` | with `-c`: print nothing; the exit status tells the result |
| `--strict` | with `-c`: fail on improperly formatted lines |
| `-w`, `--warn` | with `-c`: report each improperly formatted line |

Names that hold a backslash or a newline are written escaped (`\n`, `\\`)
after a leading `\`, as GNU does. Check mode reads GNU lines (`HASH  NAME`,
`HASH *NAME`), BSD `--tag` lines, escaped names, CRLF line ends, upper-case
hex and `#` comments. Short options combine (`-cw`), options may follow file
names, long options may be shortened to a unique prefix (`--stat`), and `--`
ends the options.

Exit status: `0` on success; `1` if a file could not be read, a checksum did
not match, a list held no valid line, or the command line was invalid (GNU
sha256sum uses `1` for all of them).

## How the hash works

[`source/hash/sha256.loup`](source/hash/sha256.loup) is FIPS 180-4 SHA-256 in
about 160 lines of Loup, comments included. The Lite edition of Loup 1.26.0
has no crypto library, and Loup's sized integers (`uint32`) throw
`NumericOverflowError` instead of wrapping, so the 32-bit words live in
64-bit `int`s: every sum is masked with `& 0xFFFFFFFF`, and a rotation is two
shifts and a mask. Whole 64-byte blocks are taken straight from the input;
only the last partial block is copied for padding. The native binary hashes
10 MB in about 0.15 s.

## Differences from GNU sha256sum

- Each input is read whole before it is hashed (Loup 1.26.0 has no
  streaming reads), so memory grows with the file and an endless input such
  as `/dev/zero` never finishes.
- A file that exists but cannot be read (no read permission) stops the
  native binary with the runtime's message, e.g.
  `IoError: read_text failed on 'secret': Permission denied (os error 13)`,
  and status 1; later files are not read. Loup has no `stat()` to check
  permissions first and the native runtime's `IoError` cannot be caught.
  Missing files and directories are reported as GNU does.
- File names in error messages are quoted as GNU quotes them in a UTF-8
  locale; bytes that are not valid UTF-8 are printed as they are rather
  than as `$'\351'`.
- `--binary` and `--text` only change the `*`/space marker; as on any
  GNU/Linux system, the digest is the same.
- Only SHA-256: there is no `--algorithm` or `--length` (those belong to
  GNU's `cksum`).
- `--version` prints a single line, and `--help` is shorter.

## Layout

```text
source/main.loup             # entry point
source/appinfo.loup          # name, version, exit statuses
source/cli/args.loup         # GNU getopt-style options, prefixes, invalid combinations
source/cli/usage.loup        # --help and --version text
source/cli/app.loup          # run(): parse, --help/--version, run_sha256sum, exit status
source/hash/sha256.loup      # SHA-256 in pure Loup
source/commands/lines.loup   # output lines, name escaping and quoting, checksum-line parsing
source/commands/sha256sum.loup  # hashing and check mode, as a Report of output lines
tests/*_test.loup            # unit tests (make test), NIST known answers included
tests/fixtures/              # files and checksum lists read by the unit tests
tests/e2e.sh                 # end-to-end tests of build/sha256sum (make e2e)
specs/sha256sum/             # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
