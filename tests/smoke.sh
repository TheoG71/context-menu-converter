#!/usr/bin/env bash
# Smoke test: exercises bin/file-convert and checks the
# result. Run it from anywhere: ./tests/smoke.sh
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO/bin/file-convert"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() { # check <description> <expected-file-type-substring> <file>
    if [ -f "$3" ] && file -b "$3" | grep -qi "$2"; then
        printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass + 1))
    else
        printf '  \033[31m✗\033[0m %s (got: %s)\n' "$1" "$(file -b "$3" 2>&1)"; fail=$((fail + 1))
    fi
}

# Fixtures are generated with whichever ImageMagick is installed:
# 7 provides "magick", 6 provides "convert".
IM=$(command -v magick || command -v convert) || {
    echo "ImageMagick is required to run these tests"; exit 77
}
"$IM" -size 40x40 xc:red "$TMP/a.webp" 2>/dev/null || {
    echo "this ImageMagick build has no webp support"; exit 77
}
"$IM" -size 40x40 xc:blue "$TMP/b.webp" 2>/dev/null

"$BIN" png "$TMP/a.webp" >/dev/null
check "webp → png" "PNG image" "$TMP/a.png"

"$BIN" jpg "$TMP/a.webp" >/dev/null
check "webp → jpg" "JPEG image" "$TMP/a.jpg"

"$BIN" png "$TMP/a.webp" >/dev/null
check "no overwrite (a-1.png created)" "PNG image" "$TMP/a-1.png"

"$BIN" png "$TMP/a.webp" "$TMP/b.webp" >/dev/null
check "multiple files: a-2.png" "PNG image" "$TMP/a-2.png"
check "multiple files: b.png" "PNG image" "$TMP/b.png"

# A truncated PNG: file(1) still calls it an image, so it reaches ImageMagick,
# which is the failure path we want to check.
head -c 40 "$TMP/a.png" > "$TMP/broken.png"
if "$BIN" jpg "$TMP/broken.png" >/dev/null 2>&1; then
    printf '  \033[31m✗\033[0m broken input should exit non-zero\n'; fail=$((fail + 1))
elif [ -e "$TMP/broken.jpg" ]; then
    printf '  \033[31m✗\033[0m broken input left a stray output file\n'; fail=$((fail + 1))
else
    printf '  \033[32m✓\033[0m broken input fails cleanly\n'; pass=$((pass + 1))
fi

# --- documents (LibreOffice) --------------------------------------------------
soffice_bin=$(command -v soffice || command -v libreoffice) || soffice_bin=""
mkdir -p "$TMP/one" "$TMP/two"
if [ -n "$soffice_bin" ]; then
    printf 'Rapport.\n' > "$TMP/one/doc.txt"
    "$soffice_bin" --headless --convert-to odt --outdir "$TMP/one" "$TMP/one/doc.txt" >/dev/null 2>&1
    printf 'Autre.\n' > "$TMP/two/doc.txt"
    "$soffice_bin" --headless --convert-to odt --outdir "$TMP/two" "$TMP/two/doc.txt" >/dev/null 2>&1
fi

# LibreOffice can be installed yet unable to load anything — it is broken that
# way inside a bare Arch build container, for instance. Judge it by whether it
# just produced a document, not by whether the binary exists, so a package
# build is never failed by its build environment.
if [ -f "$TMP/one/doc.odt" ] && [ -f "$TMP/two/doc.odt" ]; then
    "$BIN" pdf "$TMP/one/doc.odt" >/dev/null
    check "odt → pdf" "PDF document" "$TMP/one/doc.pdf"

    # Same basename in two directories: LibreOffice writes every output into one
    # directory, so this is where results would overwrite each other.
    "$BIN" pdf "$TMP/one/doc.odt" "$TMP/two/doc.odt" >/dev/null
    check "same basename, different dirs: one/doc-1.pdf" "PDF document" "$TMP/one/doc-1.pdf"
    check "same basename, different dirs: two/doc.pdf" "PDF document" "$TMP/two/doc.pdf"

    # A selection holding both kinds must route each file to the right engine.
    "$BIN" pdf "$TMP/b.webp" "$TMP/two/doc.odt" >/dev/null
    check "mixed selection: image → pdf" "PDF document" "$TMP/b.pdf"
    check "mixed selection: document → pdf" "PDF document" "$TMP/two/doc-1.pdf"
elif [ -z "$soffice_bin" ]; then
    printf '  \033[33m-\033[0m LibreOffice absent, document tests skipped\n'
else
    printf '  \033[33m-\033[0m LibreOffice present but cannot convert here, document tests skipped\n'
fi

# --- progress display ---------------------------------------------------------
# Run under a pseudo-terminal, which is the branch that prints a bar; the
# notification branch needs a session bus and cannot be exercised here.
"$IM" -size 3000x3000 plasma:fractal "$TMP/large.png" 2>/dev/null
if python3 - "$BIN" "$TMP/large.png" <<'PY'
import os, pty, sys, re

captured = bytearray()
pty.spawn([sys.argv[1], "webp", sys.argv[2]], lambda fd: (
    lambda d: (captured.extend(d), d)[1])(os.read(fd, 4096)))
text = captured.decode("utf-8", "replace")
frames = [f for f in text.split("\r") if "▰" in f or "▱" in f]

if not frames:
    print("no repaint: conversion finished within one poll", file=sys.stderr)
    sys.exit(2)

for frame in frames:
    bar = re.search(r"[▰▱]+", frame).group(0)
    assert len(bar) == 12, "bar is %d cells wide: %r" % (len(bar), frame)

percents = [int(m) for m in re.findall(r"([0-9]{1,3})%", text)]
assert percents, "a determinate conversion reported no percentage"
assert percents == sorted(percents), "percentage went backwards: %s" % percents
assert max(percents) <= 100, "percentage above 100: %s" % percents
assert "Converted to WEBP" in text, "summary line missing"
PY
then
    printf '  \033[32m✓\033[0m progress bar advances and ends on the summary\n'; pass=$((pass + 1))
elif [ $? -eq 2 ]; then
    printf '  \033[33m-\033[0m progress bar: conversion too fast to observe, skipped\n'
else
    printf '  \033[31m✗\033[0m progress bar is wrong\n'; fail=$((fail + 1))
fi

# The Nautilus extension is generated from a template. A botched substitution
# can still parse as Python (a/b;c/d is valid syntax), so check the values.
ext="$TMP/ext"
LIB_SRC="$REPO/integrations" LIB_I18N="$REPO/i18n/menu.tsv" BIN=/usr/bin/file-convert \
    bash -c '. "'"$REPO"'/tools/lib.sh"; FORMATS=(png jpg); emit_nautilus_extension "'"$ext"'" 4.1'
if python3 - "$ext/file-convert.py" <<'PY'
import ast, re, sys
src = open(sys.argv[1]).read()
left = re.search(r"@[A-Z_]+@", src)
assert not left, "unsubstituted placeholder %s" % left.group(0)
ast.parse(src)
ns = {}
for name in ("PROFILES", "TRANSLATIONS", "BIN"):
    line = re.search(r"^%s = (.*)$" % name, src, re.M)
    assert line, "missing %s" % name
    ns[name] = ast.literal_eval(line.group(1))
assert ns["PROFILES"]["image"][1] == ["png", "jpg"], ns["PROFILES"]["image"]
assert "image/webp" in ns["PROFILES"]["image"][0], ns["PROFILES"]["image"][0]
assert ns["PROFILES"]["document"][1] == ["pdf"], ns["PROFILES"]["document"]
assert "application/msword" in ns["PROFILES"]["document"][0]
assert ns["TRANSLATIONS"]["fr"][0] == "Convertir", ns["TRANSLATIONS"].get("fr")
PY
then
    printf '  \033[32m✓\033[0m Nautilus extension renders to usable values\n'; pass=$((pass + 1))
else
    printf '  \033[31m✗\033[0m Nautilus extension renders badly\n'; fail=$((fail + 1))
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
