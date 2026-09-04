#!/bin/sh
# One-line installer:
#
#   curl -fsSL https://raw.githubusercontent.com/TheoG71/context-menu-converter/main/get.sh | sh
#
# install.sh needs the whole source tree — tools/lib.sh, the integrations/
# templates, i18n/menu.tsv — so it cannot be piped on its own. This fetches the
# release tarball into a temporary directory, runs install.sh from it, and
# removes it again. Nothing is left behind but the files install.sh itself
# placed in your home directory.
#
# POSIX sh on purpose, so `| sh` works; the scripts it hands off to are bash.
set -eu

REPO_URL="https://github.com/TheoG71/context-menu-converter"
ACTION="install"
VERSION="${CMC_VERSION:-}"

usage() {
    cat <<EOF
Usage: curl -fsSL $REPO_URL/raw/main/get.sh | sh
       curl -fsSL $REPO_URL/raw/main/get.sh | sh -s -- [options]

  --version 1.0.0   install a specific release (default: the latest)
  --uninstall       remove everything a previous install put in your home
  -h, --help        show this help

Any other option is passed through to install.sh, which accepts:

  --formats png,jpg        image formats to offer
  --lang fr                menu language
  --only nautilus,dolphin  install for these file managers only
  --no-restart             don't restart file managers afterwards
EOF
}

die() { printf 'get.sh: %s\n' "$1" >&2; exit 1; }

# Options this script consumes itself; everything else goes to install.sh.
ARGS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --version)   VERSION="${2:?--version needs a value}"; shift 2 ;;
        --uninstall) ACTION="uninstall"; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           ARGS="$ARGS $1"; shift ;;
    esac
done

# --- fetching -----------------------------------------------------------------
# curl and wget are both common enough that requiring one specifically would
# turn away users for no reason.
if command -v curl >/dev/null 2>&1; then
    fetch()   { curl -fsSL -o "$2" "$1"; }
    # The final URL of /releases/latest names the newest tag. Reading the
    # redirect rather than the JSON API keeps this off the API's 60-requests-
    # per-hour unauthenticated limit.
    resolve() { curl -fsSLI -o /dev/null -w '%{url_effective}' "$1"; }
elif command -v wget >/dev/null 2>&1; then
    fetch()   { wget -qO "$2" "$1"; }
    resolve() { wget -qS --spider "$1" 2>&1 | awk '/^ *Location:/ { u=$2 } END { print u }'; }
else
    die "neither curl nor wget is installed"
fi

command -v tar >/dev/null 2>&1 || die "tar is required"

if [ -z "$VERSION" ]; then
    latest=$(resolve "$REPO_URL/releases/latest" 2>/dev/null) || latest=""
    VERSION=${latest##*/tag/v}
    case "$VERSION" in
        "" | *[!0-9.]*) die "could not determine the latest release — pass --version 1.0.0" ;;
    esac
fi

# --- unpack and hand off ------------------------------------------------------
TMP=$(mktemp -d) || die "could not create a temporary directory"
trap 'rm -rf "$TMP"' EXIT INT TERM

printf 'Fetching context-menu-converter %s\n' "$VERSION"
fetch "$REPO_URL/archive/refs/tags/v$VERSION.tar.gz" "$TMP/src.tar.gz" \
    || die "download failed — is $VERSION a released version?"
tar -xzf "$TMP/src.tar.gz" -C "$TMP" || die "the archive could not be extracted"

SRC="$TMP/context-menu-converter-$VERSION"
[ -x "$SRC/$ACTION.sh" ] || die "$ACTION.sh missing from the archive"

# Tells install.sh it was run this way, so it prints an uninstall command that
# actually exists for the user — there is no ./uninstall.sh in their cwd.
CMC_BOOTSTRAP="$REPO_URL/raw/main/get.sh"
export CMC_BOOTSTRAP

# Run it rather than exec it: exec would replace this shell, and the EXIT trap
# above would never fire — leaving the unpacked tree in /tmp after every run.
status=0
# shellcheck disable=SC2086  # ARGS is a deliberately word-split option list
"$SRC/$ACTION.sh" $ARGS || status=$?
exit "$status"
