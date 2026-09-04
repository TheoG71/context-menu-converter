#!/usr/bin/env bash
# Install "Convert to ..." context-menu entries for the file managers found on
# this machine. Everything lands in your home directory — no root needed.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/integrations"

FORMATS=(png jpg webp avif)
LIB_SRC="$SRC"
LIB_I18N="$REPO/i18n/menu.tsv"
# shellcheck source-path=SCRIPTDIR source=tools/lib.sh
. "$REPO/tools/lib.sh"
BINDIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
BIN="$BINDIR/file-convert"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
RESTART=1
TARGETS=()
installed=()

usage() {
    cat <<EOF
Usage: ./install.sh [options]

  --formats png,jpg,webp   image formats to offer (default: ${FORMATS[*]});
                           documents are always offered as PDF
  --lang fr                menu language, when it should differ from the
                           desktop's locale (see i18n/menu.tsv for the list)
  --only nautilus,dolphin  install for these file managers only
                           (nautilus, dolphin, thunar, nemo, caja)
  --no-restart             don't restart file managers afterwards
  -h, --help               show this help
EOF
}

say()  { printf '  %s\n' "$1"; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --formats) IFS=', ' read -r -a FORMATS <<<"${2:?--formats needs a value}"; shift 2 ;;
        --lang)    CMC_LANG="${2:?--lang needs a value}"; export CMC_LANG; shift 2 ;;
        --only)    IFS=', ' read -r -a TARGETS <<<"${2:?--only needs a value}"; shift 2 ;;
        --no-restart) RESTART=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

wanted() {
    [ ${#TARGETS[@]} -eq 0 ] && { command -v "$1" >/dev/null 2>&1; return; }
    for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done
    return 1
}

if [ -n "${CMC_LANG:-}" ] && [ "$(current_lang)" != "$CMC_LANG" ]; then
    warn "no translation for '$CMC_LANG' in i18n/menu.tsv — falling back to $(current_lang)"
fi

# --- dependencies -------------------------------------------------------------
step "Checking dependencies"
if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    ok "ImageMagick found (image conversion)"
else
    warn "ImageMagick is missing — image entries will install but fail when used."
    say "  Fedora: sudo dnf install ImageMagick | Debian/Ubuntu: sudo apt install imagemagick"
    say "  Arch: sudo pacman -S imagemagick"
fi
if command -v soffice >/dev/null 2>&1 || command -v libreoffice >/dev/null 2>&1; then
    ok "LibreOffice found (document conversion)"
else
    warn "LibreOffice is missing — document entries will install but fail when used."
    say "  Fedora: sudo dnf install libreoffice | Debian/Ubuntu: sudo apt install libreoffice"
    say "  Arch: sudo pacman -S libreoffice-fresh"
fi

# --- the converter itself -----------------------------------------------------
step "Installing the converter"
purge_legacy "$DATA"
rm -f -- "$BINDIR/image-convert"
mkdir -p "$BINDIR"
install -m 755 "$REPO/bin/file-convert" "$BIN"
ok "$BIN"
case ":$PATH:" in
    *":$BINDIR:"*) ;;
    *) warn "$BINDIR is not in your PATH (menu entries use the full path, so they still work)" ;;
esac

# --- Nautilus (GNOME) ---------------------------------------------------------
if wanted nautilus; then
    step "Nautilus (GNOME)"
    if abi=$(nautilus_abi); then
        # A previous run may have installed the Scripts fallback; leaving it
        # would show the menu twice.
        purge_script_dirs "$DATA/nautilus/scripts"
        dir="$DATA/nautilus-python/extensions"
        emit_nautilus_extension "$dir" "$abi"
        ok "extension → $dir/file-convert.py (images and documents)"
        installed+=(nautilus)
    else
        purge_script_dirs "$DATA/nautilus/scripts"
        dir="$DATA/nautilus/scripts/$(local_submenu_label)"
        emit_fm_scripts "$dir"
        ok "scripts → $dir (right-click ▸ Scripts ▸ Convert to)"
        warn "install nautilus-python for a real top-level menu, then re-run this script"
        say "  Fedora: sudo dnf install nautilus-python | Debian/Ubuntu: sudo apt install python3-nautilus"
        installed+=(nautilus)
    fi
fi

# --- Dolphin (KDE) ------------------------------------------------------------
if wanted dolphin; then
    step "Dolphin (KDE)"
    dir="$DATA/kio/servicemenus"
    emit_dolphin_servicemenu "$dir"
    ok "$dir/file-convert-*.desktop"
    installed+=(dolphin)
fi

# --- Thunar (XFCE) ------------------------------------------------------------
if wanted thunar; then
    step "Thunar (XFCE)"
    if command -v python3 >/dev/null 2>&1; then
        specs=()
        for profile in "${PROFILES[@]}"; do
            fmts=$(profile_formats "$profile" | paste -sd,)
            specs+=("$profile:$(profile_patterns "$profile"):$fmts")
        done
        python3 "$SRC/thunar/uca-edit.py" install "$BIN" "$(local_submenu_label)" "${specs[@]}"
        ok "$CONFIG/Thunar/uca.xml (existing custom actions kept)"
        installed+=(thunar)
    else
        warn "python3 is required to edit Thunar's uca.xml — skipped"
    fi
fi

# --- Nemo (Cinnamon) ----------------------------------------------------------
if wanted nemo; then
    step "Nemo (Cinnamon)"
    dir="$DATA/nemo/actions"
    emit_nemo_actions "$dir"
    ok "$dir/file-convert-*.nemo_action"
    if command -v python3 >/dev/null 2>&1; then
        names=()
        for profile in "${PROFILES[@]}"; do
            while read -r fmt; do names+=("file-convert-$profile-$fmt"); done \
                < <(profile_formats "$profile")
        done
        python3 "$SRC/nemo/layout-edit.py" install "$(local_submenu_label)" "${names[@]}"
        ok "grouped under \"$(local_submenu_label)\" in $CONFIG/nemo/actions/actions-tree.json"
    else
        warn "python3 missing: the entries will show flat instead of in a submenu"
    fi
    installed+=(nemo)
fi

# --- Caja (MATE) --------------------------------------------------------------
if wanted caja; then
    step "Caja (MATE)"
    purge_script_dirs "$CONFIG/caja/scripts" "$HOME/.gnome2/nautilus-scripts"
    dir="$CONFIG/caja/scripts/$(local_submenu_label)"
    [ -d "$HOME/.gnome2/nautilus-scripts" ] && dir="$HOME/.gnome2/nautilus-scripts/$(local_submenu_label)"
    emit_fm_scripts "$dir"
    ok "$dir (right-click ▸ Scripts ▸ Convert to)"
    installed+=(caja)
fi

# --- restart ------------------------------------------------------------------
if [ ${#installed[@]} -eq 0 ]; then
    step "Nothing installed"
    warn "no supported file manager found (nautilus, dolphin, thunar, nemo, caja)"
    exit 1
fi

if [ "$RESTART" -eq 1 ]; then
    step "Restarting file managers"
    for fm in "${installed[@]}"; do
        case "$fm" in
            nautilus) nautilus -q >/dev/null 2>&1 || true ;;
            nemo)     nemo -q     >/dev/null 2>&1 || true ;;
            caja)     caja -q     >/dev/null 2>&1 || true ;;
            thunar)   thunar -q   >/dev/null 2>&1 || true ;;
            dolphin)  kbuildsycoca6 >/dev/null 2>&1 || kbuildsycoca5 >/dev/null 2>&1 || true ;;
        esac
    done
    ok "done — reopen your file manager if a window was already showing"
else
    step "Skipped restart"
    say "run 'nautilus -q' (or the equivalent) for the menu to appear"
fi

printf '\n\033[32mInstalled for: %s\033[0m\n' "${installed[*]}"
printf 'Menu language: %s ("%s")\n' "$(current_lang)" "$(local_submenu_label)"
printf 'Images: %s | Documents: %s\n' "${FORMATS[*]}" "${DOCUMENT_FORMATS[*]}"
if [ -n "${CMC_BOOTSTRAP:-}" ]; then
    printf 'To remove everything: curl -fsSL %s | sh -s -- --uninstall\n' "$CMC_BOOTSTRAP"
else
    printf 'Run ./uninstall.sh to remove everything.\n'
fi
