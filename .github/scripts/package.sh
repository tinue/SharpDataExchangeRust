#!/usr/bin/env bash
#
# Assemble one release archive for the current platform.
#
# Invoked by .github/workflows/release.yml with:
#   MATRIX_NAME  one of: macos-arm64 | linux-x86_64 | linux-aarch64
#                        windows-x86_64 | windows-aarch64
#   TARGETS      rustc target triple already built (one per platform)
#   ARCHIVE      output file name (…​.tar.gz or …​.zip)
#
# Layout produced:
#   sharpdx-<matrix name>/{bin,lib,include}/… + LICENSE README.md library.md CHANGELOG.md

set -euo pipefail

: "${MATRIX_NAME:?}" "${TARGETS:?}" "${ARCHIVE:?}"

stage="sharpdx-${MATRIX_NAME}"
rm -rf "$stage"
mkdir -p "$stage/bin" "$stage/lib" "$stage/include"

cp include/sharpdx.h include/module.modulemap "$stage/include/"
cp LICENSE README.md library.md CHANGELOG.md "$stage/"

# One target triple per platform.
primary="${TARGETS%%,*}"
rel="target/${primary}/release"

case "$MATRIX_NAME" in
  macos-*)
    cp "$rel/sde"              "$stage/bin/"
    cp "$rel/libsharpdx.a"     "$stage/lib/"
    cp "$rel/libsharpdx.dylib" "$stage/lib/"
    ;;

  linux-*)
    cp "$rel/sde"           "$stage/bin/"
    cp "$rel/libsharpdx.a"  "$stage/lib/"
    cp "$rel/libsharpdx.so" "$stage/lib/"
    ;;

  windows-*)
    cp "$rel/sde.exe" "$stage/bin/"
    # staticlib -> sharpdx.lib ; cdylib -> sharpdx.dll + import lib sharpdx.dll.lib
    cp "$rel"/*.lib "$stage/lib/"
    cp "$rel"/sharpdx.dll "$stage/lib/"

    # Rust's std needs several Windows system import libs (sockets, CSPRNG
    # seeding, futex-based sync, ...) that `cargo build` links into sde.exe
    # automatically but a non-cargo consumer linking the raw sharpdx.lib
    # must supply explicitly, or the link fails with unresolved externals
    # like __imp_freeaddrinfo. Rather than have every such consumer
    # hand-maintain a guessed list (which silently drifts as our own
    # dependencies change), capture rustc's own authoritative answer for
    # this exact build/target and ship it alongside the lib: on
    # x86_64-pc-windows-msvc this is a space-separated list of MSVC linker
    # tokens (bare `name.lib` filenames and the occasional `/defaultlib:x`
    # flag) -- NOT the `-lname` GCC form that macOS/Linux would get, so a
    # consumer needs to pass this to the linker as native link options, not
    # treat each word as a plain library name.
    # --print=native-static-libs refuses to run when the target has multiple
    # crate-types (ours is rlib+staticlib+cdylib), so pin it to staticlib.
    # CARGO_TERM_COLOR=never: the workflow sets `always` globally so its own
    # build-step logs stay readable, but that also colors this note with
    # ANSI escapes even though stderr here is redirected to a file, not a
    # tty -- which would corrupt the captured list with a trailing "\e[0m".
    if ! CARGO_TERM_COLOR=never cargo rustc --release --target "$primary" --lib --crate-type staticlib \
        -- --print=native-static-libs 2> "$stage/lib/.native-libs-raw.txt"; then
      echo "package.sh: cargo rustc --print=native-static-libs failed:" >&2
      cat "$stage/lib/.native-libs-raw.txt" >&2
      exit 1
    fi
    if ! grep -q 'native-static-libs:' "$stage/lib/.native-libs-raw.txt"; then
      echo "package.sh: no 'native-static-libs:' note in cargo rustc output:" >&2
      cat "$stage/lib/.native-libs-raw.txt" >&2
      rm -f "$stage/lib/.native-libs-raw.txt"
      exit 1
    fi
    # Defense in depth: strip any ANSI escapes that still make it through
    # regardless of CARGO_TERM_COLOR (e.g. a future cargo defaulting to
    # `always` when it detects... whatever it detects), and collapse to one
    # trimmed line.
    grep 'native-static-libs:' "$stage/lib/.native-libs-raw.txt" \
      | sed -E 's/^.*native-static-libs: *//; s/\x1b\[[0-9;]*m//g' \
      | tr -d '\r' | xargs > "$stage/lib/native-libs-windows.txt"
    rm -f "$stage/lib/.native-libs-raw.txt"
    echo "native-libs-windows.txt: $(cat "$stage/lib/native-libs-windows.txt")"
    ;;

  *)
    echo "package.sh: unknown MATRIX_NAME '$MATRIX_NAME'" >&2
    exit 1
    ;;
esac

echo "── archive contents ──────────────────────────────"
find "$stage" -type f | sort
echo "──────────────────────────────────────────────────"

case "$ARCHIVE" in
  *.zip)    7z a -tzip "$ARCHIVE" "$stage" >/dev/null ;;
  *.tar.gz) tar czf "$ARCHIVE" "$stage" ;;
  *) echo "package.sh: unknown archive type '$ARCHIVE'" >&2; exit 1 ;;
esac

echo "wrote $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
