#!/usr/bin/env bash
# Build the archive to upload to store.kde.org (category "Dolphin Service Menus").
#
# Dolphin's "Download New Services" runs install.sh from the archive root and
# uninstall.sh when removing, so the project's own scripts do the work — they
# already install into ~/.local/share/kio/servicemenus, bake absolute paths into
# Exec= and never need root, which is what KNewStuff requires.
#
#   packaging/kde-store/build-tarball.sh [outdir]
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:-$REPO/dist}"
VERSION="$("$REPO/bin/file-convert" --version | awk '{print $2}')"
NAME="context-menu-converter-$VERSION-kde"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stage="$tmp/$NAME"
mkdir -p "$stage"

# install.sh and uninstall.sh must sit at the archive root: KNewStuff invokes
# them from there. Everything else is what they need to run.
cp "$REPO/install.sh" "$REPO/uninstall.sh" "$REPO/LICENSE" "$REPO/README.md" "$stage/"
cp -r "$REPO/bin" "$REPO/integrations" "$REPO/tools" "$REPO/i18n" "$stage/"
chmod 755 "$stage/install.sh" "$stage/uninstall.sh" "$stage/bin/file-convert"

mkdir -p "$OUT"
# No wrapper directory: KNewStuff expects install.sh at the archive root.
tar -czf "$OUT/$NAME.tar.gz" -C "$stage" .
printf 'Wrote %s\n' "$OUT/$NAME.tar.gz"
printf 'sha256 %s\n' "$(sha256sum "$OUT/$NAME.tar.gz" | cut -d' ' -f1)"
