#!/usr/bin/env bash
# Generate the Cinnamon Spices submission tree for linuxmint/cinnamon-spices-actions.
#
# A spice ships exactly one [Nemo Action], so it cannot carry the per-format
# submenu this project installs elsewhere. What it contributes instead is the
# single most common conversion as a one-click action with no dialog.
#
# The converter is copied from bin/image-convert so the spice cannot drift from
# the rest of the project.
#
#   packaging/cinnamon-spices/build-spice.sh [outdir]
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:-$REPO/dist/cinnamon-spices}"
UUID="convert-to-png@TheoG71"
VERSION="$("$REPO/bin/file-convert" --version | awk '{print $2}')"

root="$OUT/$UUID"
files="$root/files/$UUID"
rm -rf "$root"
mkdir -p "$files/po"

# --- the action itself --------------------------------------------------------
# <UUID/...> in Exec resolves relative to the installed action directory.
cat >"$root/$UUID.nemo_action.in" <<EOF
[Nemo Action]
Active=true
_Name=Convert to PNG
_Comment=Convert the selected images to PNG
Exec=<$UUID/image-convert.sh png %F>
Icon-Name=image-x-generic
Selection=notnone
Mimetypes=image/webp;image/jpeg;image/avif;image/gif;image/bmp;image/tiff;image/x-icon;image/heif;
Quote=double
EOF

cp "$REPO/bin/file-convert" "$files/image-convert.sh"
chmod 755 "$files/image-convert.sh"

# --- metadata -----------------------------------------------------------------
cat >"$root/info.json" <<EOF
{
  "author": "TheoG71"
}
EOF

# ASCII only: validate-spice rejects non-ASCII bytes anywhere in metadata.json.
cat >"$files/metadata.json" <<EOF
{
  "uuid": "$UUID",
  "name": "Convert to PNG",
  "description": "Convert images to PNG in one click, with no dialog",
  "author": "TheoG71",
  "version": "$VERSION"
}
EOF

# --- icon (must be square) ----------------------------------------------------
IM=$(command -v magick || command -v convert)
"$IM" -size 256x256 xc:none \
    -fill '#3584e4' -draw 'roundrectangle 16,16 240,240 28,28' \
    -fill '#ffffff' -draw 'circle 88,92 88,70' \
    -fill '#ffffff' -draw 'polygon 56,196 116,116 156,166 186,132 200,196' \
    -fill '#ffffff' -pointsize 46 -gravity south -annotate +0+6 'PNG' \
    "$files/icon.png"

# --- translation template -----------------------------------------------------
cat >"$files/po/$UUID.pot" <<EOF
# Translation template for $UUID.
# Copyright (C) 2026 TheoG71
# This file is distributed under the same license as the action.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: $UUID $VERSION\n"
"Report-Msgid-Bugs-To: https://github.com/TheoG71/context-menu-converter/issues\n"
"POT-Creation-Date: 2026-08-31 00:00+0000\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"Language: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

#. Name of the action
msgid "Convert to PNG"
msgstr ""

#. Comment of the action
msgid "Convert the selected images to PNG"
msgstr ""
EOF

cat >"$root/README.md" <<'EOF'
# Convert to PNG

Right-click one or more images in Nemo and convert them to PNG. No dialog, no
options to pick: one click, and the PNG appears next to the original.

The original file is kept, and an existing file is never overwritten — if
`photo.png` already exists you get `photo-1.png`.

Requires ImageMagick (`imagemagick`), which Linux Mint installs by default.

Part of [context-menu-converter](https://github.com/TheoG71/context-menu-converter),
which adds a full "Convert to ▸ PNG / JPG / WEBP / AVIF" submenu to Nemo,
Nautilus, Dolphin, Thunar and Caja.
EOF

cat >"$root/CHANGELOG.md" <<EOF
### $VERSION

* Initial release.
EOF

printf 'Wrote %s\n' "$root"
find "$root" | sed "s|$OUT/||" | sort
