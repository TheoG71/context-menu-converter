#!/usr/bin/env bash
# Generate the system-wide file-manager entries into a staging tree.
# Used by `make install`; not meant to be run directly by users.
#
#   tools/stage.sh <DESTDIR> <PREFIX> <NAUTILUS_ABI> [format]...
#
# Paths baked into the generated files use PREFIX, not DESTDIR — DESTDIR only
# says where to write them, as packaging convention requires.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DESTDIR="$1"; PREFIX="$2"; ABI="$3"; shift 3
FORMATS=("$@")
[ ${#FORMATS[@]} -gt 0 ] || FORMATS=(png jpg webp avif)

# Read by the emit_* helpers in lib.sh.
# shellcheck disable=SC2034
LIB_SRC="$REPO/integrations"
# shellcheck disable=SC2034
BIN="$PREFIX/bin/file-convert"
# shellcheck disable=SC2034
LIB_I18N="$REPO/i18n/menu.tsv"
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$REPO/tools/lib.sh"

emit_nautilus_extension "$DESTDIR$PREFIX/share/nautilus-python/extensions" "$ABI"
emit_dolphin_servicemenu "$DESTDIR$PREFIX/share/kio/servicemenus"
emit_nemo_actions "$DESTDIR$PREFIX/share/nemo/actions"

# Thunar (uca.xml) and the Nautilus/Caja script fallbacks are per-user only:
# there is no system-wide drop-in for them, so a package cannot ship them.
# Users on those file managers run ./install.sh instead.
