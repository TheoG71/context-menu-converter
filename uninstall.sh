#!/usr/bin/env bash
# Remove everything install.sh put in your home directory.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_SRC="$REPO/integrations"
LIB_I18N="$REPO/i18n/menu.tsv"
BIN=""            # unused here, but part of lib.sh's contract
FORMATS=()
# shellcheck source-path=SCRIPTDIR source=tools/lib.sh
. "$REPO/tools/lib.sh"
BINDIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

removed=0
drop() {
    [ -e "$1" ] || return 0
    rm -rf -- "$1"
    printf '  \033[32m✓\033[0m removed %s\n' "$1"
    removed=$((removed + 1))
}

printf '\n\033[1mRemoving image-convert\033[0m\n'
# Names from this version and from earlier ones, so upgrading never leaves a
# stale menu entry behind.
drop "$BINDIR/file-convert"
drop "$BINDIR/image-convert"
drop "$DATA/nautilus-python/extensions/file-convert.py"
drop "$DATA/nautilus-python/extensions/image-convert.py"
rm -rf "$DATA/nautilus-python/extensions/__pycache__"
# The Scripts folder is named after the submenu label, which depends on the
# language the install ran in — so try every label the table knows, and only
# remove a folder that holds nothing but our own scripts.
while read -r label; do
    for parent in "$DATA/nautilus/scripts" "$CONFIG/caja/scripts" "$HOME/.gnome2/nautilus-scripts"; do
        if is_our_script_dir "$parent/$label"; then
            drop "$parent/$label"
        fi
    done
done < <(all_labels)
for f in "$DATA/kio/servicemenus"/file-convert-*.desktop \
         "$DATA/kio/servicemenus/image-convert.desktop"; do
    drop "$f"
done
for f in "$DATA/nemo/actions"/file-convert-*.nemo_action \
         "$DATA/nemo/actions"/image-convert-*.nemo_action; do
    drop "$f"
done

if [ -f "$CONFIG/nemo/actions/actions-tree.json" ] && command -v python3 >/dev/null 2>&1; then
    python3 "$REPO/integrations/nemo/layout-edit.py" uninstall
    printf '  \033[32m✓\033[0m cleaned %s\n' "$CONFIG/nemo/actions/actions-tree.json"
    removed=$((removed + 1))
fi

if [ -f "$CONFIG/Thunar/uca.xml" ] && command -v python3 >/dev/null 2>&1; then
    python3 "$REPO/integrations/thunar/uca-edit.py" uninstall
    printf '  \033[32m✓\033[0m cleaned %s\n' "$CONFIG/Thunar/uca.xml"
    removed=$((removed + 1))
fi

for q in nautilus nemo caja thunar; do
    if command -v "$q" >/dev/null 2>&1; then
        "$q" -q >/dev/null 2>&1 || true
    fi
done
kbuildsycoca6 >/dev/null 2>&1 || kbuildsycoca5 >/dev/null 2>&1 || true

if [ "$removed" -eq 0 ]; then
    printf '\nNothing to remove — it was not installed.\n'
else
    printf '\n\033[32mDone (%s item(s) removed).\033[0m Converted files you created are untouched.\n' "$removed"
fi
