# SharpDataExchange (`sde`)

Offline **tokenize / de-tokenize** of Sharp PC-1500 / PC-1600 BASIC — no Java
runtime, a single self-contained binary. This is the Rust reimplementation of the
`convert` verb from the Java
[`SharpDataExchange`](../SharpDataExchange), with **byte-identical output** to the
Java `convert` on the checked-in fixtures.

Embedding this in your own application (C / C++ / Swift / Rust)? See
[`library.md`](library.md).

## Install

### From a release

Download the archive for your platform from the
[Releases](../../releases) page and put `bin/sde` somewhere on your `PATH`. Each
archive also contains the C library and header (see `library.md`), the license,
and this document.

| archive | platform |
|---|---|
| `sharpdx-macos-universal.tar.gz` | macOS 12+ (Apple Silicon + Intel) |
| `sharpdx-linux-x86_64.tar.gz` | Linux x86-64 (glibc 2.35+) |
| `sharpdx-linux-aarch64.tar.gz` | Linux arm64 (glibc 2.35+) |
| `sharpdx-windows-x86_64.zip` | Windows 10+ x64 |
| `sharpdx-windows-aarch64.zip` | Windows 11 arm64 |

### From source

```
cargo build --release
```

`target/release/sde` is the CLI; it links only the system C library.

## Usage

```
sde convert [options] <infile> [<outfile>]
```

Direction is chosen from **file content**, not the file name:

* an ASCII listing in → tokenized `.bbin` out (CE-158 or PC-1600 header + payload);
* a tokenized file in (header required) → `.bas` listing out.

With no `<infile>` and data on stdin, `sde` reads stdin and writes the converted
bytes to stdout.

```
sde convert myprog.bas                        # -> myprog.bbin  (CE-158 header)
sde convert -d pc1600 myprog.bas out.bbin     # -> out.bbin     (PC-1600 header)
sde convert myprog.bbin                        # -> myprog.bas   (listing)
cat myprog.bas | sde convert > myprog.bbin     # stdin -> stdout
```

### Options

| option | meaning |
|---|---|
| `-d, --device pc1500\|pc1500a\|pc1600\|pc1600emul` | keyword table + header flavor when **tokenizing** (default `pc1500`). Ignored when de-tokenizing — the device is read from the input header. |
| `-v, --verbose` | verbose logging |

If `<outfile>` is omitted the result is written next to the input with the target
extension (`.bbin` when tokenizing, `.bas` when de-tokenizing).

## Scope

Prototype: `convert` only — no `get` / `put` / `terminal`, no serial I/O, no
Variables / Reserve-Area conversion, no cassette headers. PC-1600-only token
values are limited to what the Java `Pc1600Keywords.java` lists (no PC-1600 ROM
source exists); unknown `>= 0xE0` byte pairs pass through opaquely.

The one known fixture difference is the CE-158 header *filename* field — the Java
code upper-cases it, the historical fixture stored it lower-case; `testsuite.md`
marks those header bytes "don't care". Payloads match exactly.

## Development

```
cargo test          # byte-parity, round-trip, and C-ABI tests
cargo fmt
cargo clippy --all-targets -- -D warnings
```

`src/keywords.rs` is generated from the Java `device/*Keywords.java` sources by
`tools/extract_keywords.py`:

```
python3 tools/extract_keywords.py            # rewrite src/keywords.rs
python3 tools/extract_keywords.py --check    # CI drift check (also a cargo test)
```

Releases are cut with [`bin/release`](bin/release); see the comment header in that
script and [`CHANGELOG.md`](CHANGELOG.md).

## License

[Polyform Noncommercial License 1.0.0](LICENSE) — free for any noncommercial
purpose. Copyright 2026 Martin Erzberger.
