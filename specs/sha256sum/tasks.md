# Tasks: sha256sum

- [x] 1. SHA-256 in pure Loup with masked 64-bit arithmetic, and NIST known-answer tests
  - _Requirements: 1.1, 1.4_
- [x] 2. Parse options: short groups, long prefixes, `--`, help/version, invalid combinations
  - _Requirements: 2.4, 4.1, 4.2, 4.4_
- [x] 3. Hash files and standard input; text, binary, `--tag` and `-z` lines with name escaping
  - _Requirements: 1.2, 1.3, 2.1, 2.2, 2.3_
- [x] 4. Parse checksum lines (GNU, BSD, escaped, single blank, CRLF, comments)
  - _Requirements: 3.1_
- [x] 5. Check mode: results, warnings, `--quiet`, `--status`, `-w`, `--strict`, `--ignore-missing`, exit status
  - _Requirements: 3.2, 3.3, 3.4, 3.5_
- [x] 6. Missing files and directories reported with GNU's quoting
  - _Requirements: 4.3_
- [x] 7. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
