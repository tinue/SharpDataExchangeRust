# TODO

## 1. Abbreviations via keyword ordering (not an explicit abbreviation list)

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

## 2. PC-1600 abbreviations + keyword ordering

The Java `Pc1600Keywords.java` defines no abbreviations ("not documented in the
manuals"), so our PC-1600 path currently expands nothing. But the PC-1600 **does**
support abbreviations. Same research as item 1, for the PC-1600:
- Recover the PC-1600 keyword table order (no PC-1600 ROM source in the corpus — needs a
  PC-1600 ROM dump / PockEmul, or hardware observation).
- Determine the CE-150 / CE-158 interaction for the PC-1600 match order.

## 3. GitHub Actions release matrix — DONE

`.github/workflows/ci.yml` (fmt/clippy, keyword-drift, `cargo test` on the three
native OSes, plus a cross-build sanity job for all five targets) and
`.github/workflows/release.yml` (tag-triggered: builds macOS universal + Linux
x86_64/arm64 + Windows x64/arm64, bundles `sde` + `libsharpdx.{a,so,dylib,dll}` +
`include/` + docs per platform, publishes the GitHub release). Releases are cut
with `bin/release` (see its header). `-pre` tags publish a re-cuttable
pre-release; `bin/release --release` squash-merges to `main` and tags the real
version.

Open follow-ups:
- Fill in the real repo owner in the `CHANGELOG.md` compare/tag links (currently
  `OWNER`).
- Native Linux arm64 runners (`ubuntu-22.04-arm` / `ubuntu-24.04-arm`) are used;
  fall back to cross-compilation if those labels are ever unavailable.
