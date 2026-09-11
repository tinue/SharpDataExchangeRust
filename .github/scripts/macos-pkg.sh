#!/usr/bin/env bash
#
# Build the signed macOS `.pkg` installer for `sde`.
#
# Usage:
#   macos-pkg.sh <signed-sde-path> <version> <output-pkg-path>
#
# Environment:
#   INSTALLER_IDENTITY   "Developer ID Installer: … (TEAMID)" — required to sign.
#                        If unset, an UNSIGNED product .pkg is produced (local
#                        dry-run only; Installer will refuse it on other Macs).
#
# The component payload stages `sde` at
#   /usr/local/lib/ch.erzberger.SharpDataExchange/sde
# and .github/macos/scripts/postinstall moves it to /usr/local/bin (all users)
# or ~/.local/bin (current user), keyed off whether it runs as root.

set -euo pipefail

SDE_BIN=${1:?usage: macos-pkg.sh <signed-sde-path> <version> <output-pkg-path>}
VERSION=${2:?missing version}
OUT_PKG=${3:?missing output pkg path}

IDENTIFIER="ch.erzberger.SharpDataExchange"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # .github/
DIST_SRC="$HERE/macos/distribution.xml"
SCRIPTS_DIR="$HERE/macos/scripts"

[ -f "$SDE_BIN" ]   || { echo "macos-pkg.sh: no such file: $SDE_BIN" >&2; exit 1; }
[ -f "$DIST_SRC" ]  || { echo "macos-pkg.sh: missing $DIST_SRC" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stage="$tmp/root"

install -d -m 0755 "$stage/usr/local/lib/$IDENTIFIER"
install -m 0755 "$SDE_BIN" "$stage/usr/local/lib/$IDENTIFIER/sde"
xattr -cr "$stage"   # drop quarantine / provenance xattrs so no ._ files ship

echo "── pkgbuild (component) ──────────────────────────"
export COPYFILE_DISABLE=1
pkgbuild \
    --root "$stage" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --scripts "$SCRIPTS_DIR" \
    --install-location / \
    "$tmp/component.pkg"

sed "s/__VERSION__/$VERSION/g" "$DIST_SRC" > "$tmp/distribution.xml"

echo "── productbuild (distribution) ──────────────────"
productbuild \
    --distribution "$tmp/distribution.xml" \
    --package-path "$tmp" \
    "$tmp/unsigned.pkg"

if [ -n "${INSTALLER_IDENTITY:-}" ]; then
    echo "── productsign ($INSTALLER_IDENTITY) ────────────"
    productsign --sign "$INSTALLER_IDENTITY" "$tmp/unsigned.pkg" "$OUT_PKG"
    pkgutil --check-signature "$OUT_PKG"
else
    echo "WARNING: INSTALLER_IDENTITY unset — producing an UNSIGNED .pkg" >&2
    cp "$tmp/unsigned.pkg" "$OUT_PKG"
fi

echo "wrote $OUT_PKG ($(du -h "$OUT_PKG" | cut -f1))"
