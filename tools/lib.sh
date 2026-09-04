#!/usr/bin/env bash
# Shared generation logic: turns the templates in integrations/ into the real
# files a file manager reads. Sourced by install.sh (per-user, into $HOME) and
# by tools/stage.sh (system-wide, into a packaging staging tree).
#
# Callers must set: LIB_SRC (path to integrations/), BIN (path file-convert
# will live at), FORMATS (array of target formats) and LIB_I18N (path to
# i18n/menu.tsv).

# BIN, LIB_SRC and FORMATS are part of the contract with the caller.
# shellcheck disable=SC2154  # they are assigned by whoever sources this file
# Two kinds of file get a menu, each with its own MIME types and targets:
# images go through ImageMagick, documents through LibreOffice.
PROFILES=(image document)

IMAGE_MIMETYPES="image/png;image/jpeg;image/webp;image/avif;image/gif;image/bmp;image/tiff;image/x-icon;image/heif;"
IMAGE_PATTERNS="*.png;*.jpg;*.jpeg;*.webp;*.avif;*.gif;*.bmp;*.tif;*.tiff;*.heic;*.ico"

DOCUMENT_MIMETYPES="application/vnd.oasis.opendocument.text;application/vnd.oasis.opendocument.text-template;application/vnd.oasis.opendocument.spreadsheet;application/vnd.oasis.opendocument.presentation;application/vnd.oasis.opendocument.graphics;application/msword;application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.ms-excel;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;application/vnd.ms-powerpoint;application/vnd.openxmlformats-officedocument.presentationml.presentation;application/rtf;text/rtf;text/csv;"
DOCUMENT_PATTERNS="*.odt;*.ott;*.ods;*.odp;*.odg;*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.rtf;*.csv"

# Documents only ever go to PDF; images take whatever the caller asked for.
DOCUMENT_FORMATS=(pdf)

# profile_mimetypes / profile_patterns / profile_formats <profile>
profile_mimetypes() {
    case "$1" in
        image) printf '%s' "$IMAGE_MIMETYPES" ;;
        document) printf '%s' "$DOCUMENT_MIMETYPES" ;;
    esac
}

profile_patterns() {
    case "$1" in
        image) printf '%s' "$IMAGE_PATTERNS" ;;
        document) printf '%s' "$DOCUMENT_PATTERNS" ;;
    esac
}

# shellcheck disable=SC2153  # FORMATS is the caller's array, not a typo
profile_formats() {
    case "$1" in
        image) printf '%s\n' "${FORMATS[@]}" ;;
        document) printf '%s\n' "${DOCUMENT_FORMATS[@]}" ;;
    esac
}

# every target format across profiles, deduplicated, for menus that cannot
# filter by file type (the Scripts folders)
all_formats() {
    local p
    for p in "${PROFILES[@]}"; do profile_formats "$p"; done | awk '!seen[$0]++'
}

# --- translations -------------------------------------------------------------
# i18n/menu.tsv holds one row per language: lang, submenu label, item label,
# item tooltip. Menu entries are localised two different ways depending on what
# the file manager supports: .desktop and .nemo_action carry every language at
# once as Key[lang]= lines, so a system-wide package serves every user; Thunar
# and the Scripts folders have no such mechanism, so they get the language of
# whoever runs install.sh.

# tr_lookup <lang> <column 2..4> — echo that string, falling back to English.
tr_lookup() {
    awk -F'\t' -v want="$1" -v col="$2" '
        /^#/ || NF < 4 { next }
        $1 == want { print $col; found = 1; exit }
        $1 == "en" { fallback = $col }
        END { if (!found) print fallback }
    ' "$LIB_I18N"
}

# tr_langs — echo every language code in the table except the "en" fallback.
tr_langs() {
    awk -F'\t' '!/^#/ && NF >= 4 && $1 != "en" { print $1 }' "$LIB_I18N"
}

# current_lang — the language of the user running this script, as found in the
# table: exact match first (pt_BR), then the bare language (pt), else en.
# CMC_LANG overrides the locale, for a desktop running in one language whose
# owner wants the menu in another.
current_lang() {
    local l="${CMC_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}"
    l="${l%%.*}"; l="${l%%@*}"
    local base="${l%%_*}"
    local known
    known=$(awk -F'\t' '!/^#/ && NF >= 4 { print $1 }' "$LIB_I18N")
    if printf '%s\n' "$known" | grep -qx "$l"; then echo "$l"
    elif printf '%s\n' "$known" | grep -qx "$base"; then echo "$base"
    else echo en
    fi
}

# submenu_label <lang> — the "Convert" submenu label in that language.
submenu_label() { tr_lookup "$1" 2; }

# local_submenu_label — the same, in the language of the user running this.
local_submenu_label() { tr_lookup "$(current_lang)" 2; }

# all_labels — every submenu label the table knows, English first.
all_labels() {
    tr_lookup en 2
    tr_langs | while read -r l; do tr_lookup "$l" 2; done
}

# is_our_script_dir <dir> — true when dir exists and holds nothing but scripts
# this project generated. Guards against deleting a folder that merely shares
# the label.
is_our_script_dir() {
    local dir="$1" f
    [ -d "$dir" ] || return 1
    for f in "$dir"/*; do
        [ -e "$f" ] || continue
        grep -qE "file-convert|image-convert" "$f" 2>/dev/null || return 1
    done
    return 0
}

# purge_script_dirs <parent>... — silently drop Scripts folders left by an
# earlier install, whatever language it ran in. Without this, installing again
# under a different language would leave the old folder behind next to the new.
purge_script_dirs() {
    local label parent
    while read -r label; do
        for parent in "$@"; do
            if is_our_script_dir "$parent/$label"; then
                rm -rf -- "${parent:?}/${label:?}"
            fi
        done
    done < <(all_labels)
}

# purge_legacy <data-dir> — remove menu entries installed under the names this
# project used before. Installing over an older version would otherwise leave
# both sets in place and show the menu twice.
purge_legacy() {
    local data="$1"
    rm -f -- "$data/nautilus-python/extensions/image-convert.py"
    rm -rf -- "$data/nautilus-python/extensions/__pycache__"
    rm -f -- "$data/kio/servicemenus/image-convert.desktop"
    rm -f -- "$data"/nemo/actions/image-convert-*.nemo_action
}

# render <template> [NAME=VALUE]... — substitute @PLACEHOLDERS@ on stdout.
# Only @BIN@ is substituted implicitly; everything else, MIME lists included,
# is passed as a NAME=VALUE pair so each template gets the shape it needs.
render() {
    local tpl="$1"; shift
    local out; out=$(cat "$tpl")
    out="${out//@BIN@/$BIN}"
    local pair
    for pair in "$@"; do out="${out//@${pair%%=*}@/${pair#*=}}"; done
    printf '%s\n' "$out"
}

# emit_nautilus_extension <dir> <nautilus-abi>
emit_nautilus_extension() {
    local dir="$1" abi="$2" profile
    mkdir -p "$dir"

    # One dict, profile -> (mime set, formats), so the extension offers the
    # right targets for whatever was right-clicked.
    local profiles="{"
    for profile in "${PROFILES[@]}"; do
        local mimes formats
        # shellcheck disable=SC2046  # word splitting turns ';' into items
        mimes="{$(printf '"%s", ' $(profile_mimetypes "$profile" | tr ';' ' '))}"
        formats="[$(profile_formats "$profile" | while read -r f; do printf '"%s", ' "$f"; done)]"
        profiles+="$(printf '"%s": (%s, %s), ' "$profile" "$mimes" "$formats")"
    done
    profiles+="}"

    # The extension picks the language at runtime, so the whole table is
    # embedded as a Python dict.
    local table="{"
    local lang
    while read -r lang; do
        table+="$(printf '"%s": ("%s", "%s"), ' "$lang" "$(tr_lookup "$lang" 2)" "$(tr_lookup "$lang" 4)")"
    done < <(printf 'en\n'; tr_langs)
    table+="}"

    render "$LIB_SRC/nautilus/file-convert.py" \
        "PROFILES_PY=$profiles" "NAUTILUS_ABI=$abi" "TRANSLATIONS=$table" \
        >"$dir/file-convert.py"
}

# emit_dolphin_servicemenu <dir> — one .desktop per profile, each with a
# [Desktop Action] per target format. Two files rather than one because a
# service menu carries a single MimeType list.
emit_dolphin_servicemenu() {
    local dir="$1" profile fmt lang out
    mkdir -p "$dir"

    # .desktop carries every translation at once, so one system-wide file
    # serves users of any language.
    local submenu_lines
    submenu_lines="X-KDE-Submenu=$(tr_lookup en 2)"
    while read -r lang; do
        submenu_lines+=$'\n'"X-KDE-Submenu[$lang]=$(tr_lookup "$lang" 2)"
    done < <(tr_langs)

    for profile in "${PROFILES[@]}"; do
        out="$dir/file-convert-$profile.desktop"
        local actions=""
        while read -r fmt; do actions+="$fmt;"; done < <(profile_formats "$profile")
        render "$LIB_SRC/dolphin/file-convert.desktop" \
            "ACTIONS=$actions" "SUBMENU_LINES=$submenu_lines" \
            "MIMETYPES=$(profile_mimetypes "$profile")" >"$out"
        while read -r fmt; do
            cat >>"$out" <<EOF

[Desktop Action $fmt]
Name=${fmt^^}
Icon=document-save
Exec="$BIN" $fmt %F
EOF
        done < <(profile_formats "$profile")
        # KDE requires service menus to be executable to consider them authorized.
        chmod 755 "$out"
    done
}

# emit_nemo_actions <dir> — one .nemo_action per profile and format.
#
# Nemo shows actions flat; the submenu is a separate per-user layout file (see
# integrations/nemo/layout-edit.py). So each entry carries the standalone item
# label, in every language, the same way the .desktop does.
emit_nemo_actions() {
    local dir="$1" profile fmt lang name_lines comment_lines
    mkdir -p "$dir"
    for profile in "${PROFILES[@]}"; do
        while read -r fmt; do
            # shellcheck disable=SC2059  # the table supplies the format string
            name_lines=$(printf "Name=$(tr_lookup en 3)" "${fmt^^}")
            # shellcheck disable=SC2059
            comment_lines=$(printf "Comment=$(tr_lookup en 4)" "${fmt^^}")
            while read -r lang; do
                # shellcheck disable=SC2059
                name_lines+=$'\n'$(printf "Name[$lang]=$(tr_lookup "$lang" 3)" "${fmt^^}")
                # shellcheck disable=SC2059
                comment_lines+=$'\n'$(printf "Comment[$lang]=$(tr_lookup "$lang" 4)" "${fmt^^}")
            done < <(tr_langs)
            render "$LIB_SRC/nemo/action.nemo_action" "FMT=$fmt" \
                "MIMETYPES=$(profile_mimetypes "$profile")" \
                "NAME_LINES=$name_lines" "COMMENT_LINES=$comment_lines" \
                >"$dir/file-convert-$profile-$fmt.nemo_action"
        done < <(profile_formats "$profile")
    done
}

# emit_fm_scripts <dir> — executable scripts (Nautilus fallback, Caja)
emit_fm_scripts() {
    local dir="$1" fmt
    mkdir -p "$dir"
    # A Scripts folder cannot filter by file type, so it offers every target
    # and lets file-convert decide what to do with what it is given.
    while read -r fmt; do
        render "$LIB_SRC/nautilus/script.sh" "FMT=$fmt" >"$dir/${fmt^^}"
        chmod 755 "$dir/${fmt^^}"
    done < <(all_formats)
}

# nautilus_abi — echo the Nautilus GIR version usable on this machine, if any.
#
# The version is not stable: GNOME 50 ships Nautilus-4.1 where GNOME 43-48
# shipped 4.0, and GNOME 42 and older shipped 3.0. So ask GIRepository what
# exists before falling back to a probe list — and note that the call to reach
# it was renamed (get_default -> dup_default) between PyGObject releases.
nautilus_abi() {
    local abi
    abi=$(python3 - <<'PY' 2>/dev/null
import gi

candidates = []
try:
    gi.require_version("GIRepository", "3.0")
except Exception:
    pass
try:
    from gi.repository import GIRepository

    default = getattr(GIRepository.Repository, "dup_default", None) or \
        GIRepository.Repository.get_default
    candidates = sorted(
        default().enumerate_versions("Nautilus"),
        key=lambda v: [int(part) for part in v.split(".")],
        reverse=True,
    )
except Exception:
    pass

for version in candidates + ["4.2", "4.1", "4.0", "3.0"]:
    try:
        gi.require_version("Nautilus", version)
        from gi.repository import Nautilus  # noqa: F401
    except Exception:
        continue
    print(version)
    break
PY
)
    [ -n "$abi" ] || return 1
    echo "$abi"
}
