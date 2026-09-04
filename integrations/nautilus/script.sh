#!/usr/bin/env bash
# context-menu-converter — file-manager script (Nautilus / Caja fallback, no extension needed)
IFS=$'\n'
paths="${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-${CAJA_SCRIPT_SELECTED_FILE_PATHS:-}}"
# shellcheck disable=SC2086
exec "@BIN@" "@FMT@" $paths
