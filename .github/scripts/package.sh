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
