# TODO

## 1. Tokenize CRLF-terminated input (real-world Windows `.bas` files)

The scanner treats bytes literally, so a source listing with `\r\n` line endings
produces an extra `0x0D` per line in the tokenized payload (this is what broke
the Windows CI run before `.gitattributes` forced `eol=lf` on the fixtures).

`.gitattributes` only fixes *this repo's checkout*. A real `.bas` file authored or
edited on Windows will almost always have CR/LF endings — unless it was checked
out from a repo that sets `text=auto eol=lf` *and* the editor honours it. So the
CLI and the C ABI will mis-tokenize typical Windows input.

Decide and implement:
- **a) Where to normalize.** Strip a trailing `\r` from each line (and handle a
  lone `\r` as a terminator?) at the entry of `convert()` for ASCII input, before
  the scanner runs. Keep the verbatim/string states in mind — a `\r` inside a
  quoted string or a `REM`/verbatim tail is almost certainly still junk to drop,
  but confirm.
- **b) Parity check.** Confirm the Java `SharpDataExchange` `convert` also
  normalizes CR/LF (it very likely does, since it is used from Windows). If Java
  keeps `\r`, document the deliberate divergence; if it strips, add a fixture
  with CRLF endings to `tests/byte_parity.rs` so the behaviour is locked in.
- **c) De-tokenize direction.** Output uses `\r` (`0x0D`) as the PC-1500 line
  terminator; leave that as-is, but note whether a `--crlf` / platform-aware
  option is wanted for the listing written back out on Windows.

## 2. macOS build: Apple Silicon only (drop x86_64)

The release currently ships a `lipo` universal macOS archive (`arm64` +
`x86_64`). Make it arm64-only:
- `.github/workflows/release.yml`: `macos-universal` job → single
  `aarch64-apple-darwin` target; rename artifact to `sharpdx-macos-arm64.tar.gz`.
- `.github/scripts/package.sh`: drop the `lipo` branch, treat macOS like the other
  single-target platforms.
- `.github/workflows/ci.yml`: remove the `x86_64-apple-darwin` row from
  `cross-build`.
- `README.md` install table: `macOS 12+ (Apple Silicon)` and the new archive name.

## 3. Release-scaffolding loose ends

- `CHANGELOG.md` compare/tag links still say `OWNER` — change to `tinue`.
- Native Linux arm64 runners (`ubuntu-22.04-arm` / `ubuntu-24.04-arm`) are used;
  fall back to cross-compilation if those labels are ever unavailable.
- `Swatinem/rust-cache@v2` still triggers a Node 20 deprecation warning; revisit
  when a Node 24 major ships.

## 4. Abbreviations via keyword ordering (not an explicit abbreviation list)

The ROM does not store a list of valid abbreviations. It stores an **ordered list of
keywords per initial letter** and matches greedily: `P.` resolves to whatever the first
`P*` entry in that list is (`PRINT`), because the table is ordered so the intended
keyword comes first. Our port currently relies on the explicit `abbrev` field extracted
from the Java sources; replace that with ROM-order-driven resolution.

Research needed:
- **a) What is the keyword order?** Recover the per-letter ordering of the PC-1500 ROM
  keyword table (linked lists at `$C020` / `$C054` in the disassembly). This is the
  authority for which keyword a bare `X.` abbreviation expands to.
- **b) How does the order interact with CE-150 and/or CE-158?** Peripheral keywords live
  in their own token ranges (`0xE6xx`–`0xE8xx`) — determine where/whether they are
  inserted into the per-letter match order when the peripheral is attached, and how that
  affects abbreviation resolution (e.g. does `L.` change meaning with a CE-150 present?).

## 5. PC-1600 abbreviations + keyword ordering

The Java `Pc1600Keywords.java` defines no abbreviations ("not documented in the
manuals"), so our PC-1600 path currently expands nothing. But the PC-1600 **does**
support abbreviations. Same research as item 4, for the PC-1600:
- Recover the PC-1600 keyword table order (no PC-1600 ROM source in the corpus — needs a
  PC-1600 ROM dump / PockEmul, or hardware observation).
- Determine the CE-150 / CE-158 interaction for the PC-1600 match order.
