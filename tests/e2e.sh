#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), standard error and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY
#
# The cases run in a temporary directory holding the files made below, so
# output and error messages show short names.

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error and the exit status.
check_err() {
    local name=$1 want_status=$2 want_err=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        echo "    want stderr: $want_err"
        sed 's/^/    got stderr:  /' "$TMP/err" | head -5
    fi
}

ABC=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
EMPTY=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
LINE=c73b73af8851e9e91bc6b4dc12e7dace0a2bfb931c1d0b8b36ef367319f58cd1
MILLION=cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0
ZERO64=0000000000000000000000000000000000000000000000000000000000000000

cd "$TMP" || exit 1
printf 'abc' > abc
: > empty
printf 'line\n' > line
printf 'abc' > 'a b'
printf 'abc' > 'back\slash'
printf 'abc' > $'new\nline'
printf '\000\001\377\376binary' > binary
head -c 1000000 /dev/zero | tr '\0' a > million
for n in 55 56 64; do head -c $n /dev/zero | tr '\0' a > "a$n"; done
mkdir dir

# Hashing
check "one file"           0 "$ABC  abc"$'\n'                          abc
check "empty file"         0 "$EMPTY  empty"$'\n'                      empty
check "several files"      0 "$ABC  abc"$'\n'"$LINE  line"$'\n'        abc line
check "name with a space"  0 "$ABC  a b"$'\n'                          'a b'
check "NIST million a"     0 "$MILLION  million"$'\n'                  million
check "55 bytes"           0 $'9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318  a55\n' a55
check "56 bytes"           0 $'b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a  a56\n' a56
check "64 bytes"           0 $'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb  a64\n' a64
check "binary data"        0 $'3776c328ecd504b9aca9ac1cb6af174b6f503cd888c917fa3eba95cec0d67d35  binary\n' binary
IN=abc check "stdin"       0 "$ABC  -"$'\n'
IN=abc check "dash"        0 "$ABC  -"$'\n'                            -
IN=abc check "stdin twice" 0 "$ABC  -"$'\n'"$EMPTY  -"$'\n'            - -
check "-b"                 0 "$ABC *abc"$'\n'                          -b abc
check "--binary"           0 "$ABC *abc"$'\n'                          --binary abc
check "-t"                 0 "$ABC  abc"$'\n'                          -t abc
check "--tag"              0 "SHA256 (abc) = $ABC"$'\n'                --tag abc
check "--tag -b"           0 "SHA256 (abc) = $ABC"$'\n'                --tag -b abc
check "backslash escaped"  0 "\\$ABC  back\\\\slash"$'\n'              'back\slash'
check "newline escaped"    0 "\\$ABC  new\\nline"$'\n'                 $'new\nline'
check "--tag escaped"      0 "\\SHA256 (new\\nline) = $ABC"$'\n'       --tag $'new\nline'
printf '%s  abc\0%s  back\\slash\0' "$ABC" "$ABC" > want_z
check_file "-z"            0 want_z                                    -z abc 'back\slash'
check "options after files" 0 "SHA256 (abc) = $ABC"$'\n'               abc --tag
check "-- ends options"    1 ""                                        -- --tag
check_err "-- message"     1 "sha256sum: --tag: No such file or directory" -- --tag

# Hashing errors
check "missing file"       1 "$ABC  abc"$'\n'                          missing abc
check_err "missing message" 1 "sha256sum: missing: No such file or directory" missing abc
check_err "directory"      1 "sha256sum: dir: Is a directory"          dir
check_err "quoted name"    1 "sha256sum: 'no such': No such file or directory" 'no such'

# Checksum lists
printf '%s  abc\n%s  empty\n' "$ABC" "$EMPTY" > good.sum
printf 'SHA256 (abc) = %s\nSHA256 (empty) = %s\n' "$ABC" "$EMPTY" > tag.sum
printf '# comment\n%s  abc\n%s *empty\nnot a checksum\n%s  missing\n' "$ABC" "$ABC" "$EMPTY" > mixed.sum
printf '%s  missing\n' "$EMPTY" > missing.sum
printf 'junk\nmore junk\n' > junk.sum
printf '\\%s  back\\\\slash\n\\%s  new\\nline\n' "$ABC" "$ABC" > escaped.sum
printf '%s  abc\r\n\n%s  empty\r\n' "$(echo "$ABC" | tr a-f A-F)" "$EMPTY" > crlf.sum
printf '%s abc\n%s empty\n' "$ABC" "$EMPTY" > onespace.sum
printf '%s  abc\0%s  empty\0' "$ABC" "$EMPTY" > nul.sum

check "-c all OK"          0 $'abc: OK\nempty: OK\n'                   -c good.sum
check_err "-c quiet stderr" 0 ""                                       -c good.sum
check "--check BSD lines"  0 $'abc: OK\nempty: OK\n'                   --check tag.sum
check "-c mixed"           1 $'abc: OK\nempty: FAILED\nmissing: FAILED open or read\n' -c mixed.sum
check_err "-c mixed warnings" 1 "sha256sum: missing: No such file or directory
sha256sum: WARNING: 1 line is improperly formatted
sha256sum: WARNING: 1 listed file could not be read
sha256sum: WARNING: 1 computed checksum did NOT match" -c mixed.sum
check "--quiet"            1 $'empty: FAILED\nmissing: FAILED open or read\n' -c --quiet mixed.sum
check "--quiet all OK"     0 ""                                        -c --quiet good.sum
check "--status"           1 ""                                        -c --status mixed.sum
check_err "--status stderr" 1 "sha256sum: missing: No such file or directory" -c --status mixed.sum
check "--status OK"        0 ""                                        -c --status good.sum
check_err "-w"             1 "sha256sum: mixed.sum: 4: improperly formatted SHA256 checksum line
sha256sum: missing: No such file or directory
sha256sum: WARNING: 1 line is improperly formatted
sha256sum: WARNING: 1 listed file could not be read
sha256sum: WARNING: 1 computed checksum did NOT match" -c -w mixed.sum
printf '%s  abc\nbad line\n' "$ABC" > onebad.sum
check "bad line tolerated" 0 $'abc: OK\n'                              -c onebad.sum
check "--strict"           1 $'abc: OK\n'                              -c --strict onebad.sum
check "--ignore-missing"   1 $'abc: OK\nempty: FAILED\n'               -c --ignore-missing mixed.sum
check_err "nothing verified" 1 "sha256sum: missing.sum: no file was verified" -c --ignore-missing missing.sum
check_err "no checksum lines" 1 "sha256sum: junk.sum: no properly formatted checksum lines found" -c junk.sum
check_err "missing list"   1 "sha256sum: nope.sum: No such file or directory" -c nope.sum
check "escaped names"      0 $'\\back\\\\slash: OK\n\\new\\nline: OK\n' -c escaped.sum
check "CRLF, upper case"   0 $'abc: OK\nempty: OK\n'                   -c crlf.sum
check "one-space lines"    0 $'abc: OK\nempty: OK\n'                   -c onespace.sum
check "names end at NUL"   0 $'abc: OK\n'                              -c nul.sum
IN=good.sum check "list on stdin" 0 $'abc: OK\nempty: OK\n'            -c
IN=good.sum check_err "stdin list name" 1 "sha256sum: 'standard input': no properly formatted checksum lines found" -c - -

# Command line
check_err "unknown option" 1 "sha256sum: unrecognized option '--bogus'
Try 'sha256sum --help' for more information." --bogus
check_err "invalid short"  1 "sha256sum: invalid option -- 'x'
Try 'sha256sum --help' for more information." -x
check_err "ambiguous"      1 "sha256sum: option '--st' is ambiguous; possibilities: '--status' '--strict'
Try 'sha256sum --help' for more information." --st
check_err "--tag --text"   1 "sha256sum: --tag does not support --text mode
Try 'sha256sum --help' for more information." --tag --text abc
check_err "-c --tag"       1 "sha256sum: the --tag option is meaningless when verifying checksums
Try 'sha256sum --help' for more information." -c --tag good.sum
check_err "-c -z"          1 "sha256sum: the --zero option is not supported when verifying checksums
Try 'sha256sum --help' for more information." -cz good.sum
check_err "--quiet alone"  1 "sha256sum: the --quiet option is meaningful only when verifying checksums
Try 'sha256sum --help' for more information." --quiet abc
check "prefix --stat"      0 ""                                        -c --stat good.sum
check "--version"          0 $'sha256sum (loup-cmd-sha256sum) 0.1.0\n' --version
"$BIN" --help > help.txt
if [ "$(head -1 help.txt)" = "Usage: sha256sum [OPTION]... [FILE]..." ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help first line: $(head -1 help.txt)"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
