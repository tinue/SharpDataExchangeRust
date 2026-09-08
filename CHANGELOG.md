# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). While the major
version is `0`, the C ABI may change between minor versions.

`bin/release` reads the section for the version being released and uses it as the
GitHub release notes, so keep entries user-facing.

## [Unreleased]

## [0.1.0] - 2026-09-08

### Added

- ROM-style linear scanner (`src/scanner.rs`) that tokenizes Sharp PC-1500 /
  PC-1600 BASIC in one left-to-right pass with a 3-state (normal / string /
  verbatim) model, instead of a grammar.
- `sde convert` CLI: content-detected direction, `-d/--device`
  `pc1500|pc1500a|pc1600|pc1600emul`, file or stdin/stdout I/O, output-path
  derivation.
- `libsharpdx` C ABI (`sde_convert`, `sde_tokenize`, `sde_detokenize`,
  `sde_detect`, `sde_version`, `sde_last_error`, `sde_buf_free`) with a
  panic-free boundary and caller-freed buffers. Committed C header and Swift
  module map generated from `src/ffi.rs`.
- `sharpdx` Rust crate exposing the pure `convert` core.
- Byte-parity test suite against the Java `SharpDataExchange` `convert` fixtures,
  plus round-trip and C-ABI tests.
- Release archives for macOS (universal), Linux x86-64 / arm64, and Windows
  x64 / arm64, each bundling the CLI, the static and shared libraries, and the
  `include/` directory.

### Known limitations

- `convert` only — no `get` / `put` / `terminal`, serial I/O, Variables /
  Reserve-Area conversion, or cassette headers.
- PC-1600-only token values are limited to what `Pc1600Keywords.java` lists;
  unknown `>= 0xE0` byte pairs pass through opaquely.
- The CE-158 header filename field is upper-cased (the historical fixture stored
  it lower-case); `testsuite.md` marks those bytes "don't care". Payloads match
  the Java output exactly.

[Unreleased]: https://github.com/OWNER/SharpDataExchangeRust/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/OWNER/SharpDataExchangeRust/releases/tag/v0.1.0
