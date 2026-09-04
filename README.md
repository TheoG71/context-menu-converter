# context-menu-converter

[![CI](https://github.com/TheoG71/context-menu-converter/actions/workflows/ci.yml/badge.svg)](https://github.com/TheoG71/context-menu-converter/actions/workflows/ci.yml)

Right-click a file in your file manager → **Convert ▸ …**, and the converted
file lands next to the original.

- **Images** → PNG / JPG / WEBP / AVIF, through ImageMagick
- **Documents** (`.odt`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`,
  `.rtf`, `.csv`, …) → PDF, through LibreOffice

The menu offers only what suits what you clicked: PDF on a spreadsheet, image
formats on a photo, nothing at all on a file it does not handle.

The menu speaks the language of your desktop: *Convertir*, *Konvertieren*,
*Convertir*, *変換*, *Конвертировать* — 32 languages, English elsewhere.

No daemon, no root, no desktop-wide config: everything installs into your home
directory and can be removed with one command.

## Install

```sh
curl -fsSL https://github.com/TheoG71/context-menu-converter/raw/main/get.sh | sh
```

That fetches the latest release into a temporary directory, runs the installer,
and removes the directory again — nothing is left behind but the files placed in
your home directory. It needs no root, and options are passed after `--`:

```sh
curl -fsSL .../get.sh | sh -s -- --formats png,jpg --lang fr
curl -fsSL .../get.sh | sh -s -- --version 1.0.0     # pin a release
curl -fsSL .../get.sh | sh -s -- --uninstall         # remove everything
```

The installer detects the file managers you actually have and sets up each one.
Then reopen your file-manager window.

If you would rather read everything before running it, or want to work on the
project, clone it and run the same installer directly:

```sh
git clone https://github.com/TheoG71/context-menu-converter.git
cd context-menu-converter
./install.sh
```

### Requirements

- **ImageMagick**, for images — `sudo dnf install ImageMagick` /
  `sudo apt install imagemagick` / `sudo pacman -S imagemagick`
- **LibreOffice**, for documents — `sudo dnf install libreoffice` /
  `sudo apt install libreoffice` / `sudo pacman -S libreoffice-fresh`.
  Only the engine a given file needs has to be installed.
- **GNOME only, optional but recommended:** `nautilus-python`
  (`sudo dnf install nautilus-python`, `sudo apt install python3-nautilus`).
  Without it the entries still work, but they live under the *Scripts* submenu
  instead of the top level — Nautilus offers no other way for a third party to
  add a top-level entry. Install it and re-run `./install.sh` to upgrade; the
  Scripts folder is removed at that point so the menu does not appear twice.

## Supported file managers

| File manager | Desktop | Where it installs | Menu looks like |
|---|---|---|---|
| Nautilus | GNOME | `~/.local/share/nautilus-python/extensions/` | **Convert ▸ PNG** — shown on images only |
| Nautilus *(no nautilus-python)* | GNOME | `~/.local/share/nautilus/scripts/` | **Scripts ▸ Convert ▸ PNG** |
| Dolphin | KDE | `~/.local/share/kio/servicemenus/` | **Convert ▸ PNG** — shown on images only |
| Thunar | XFCE | `~/.config/Thunar/uca.xml` | **Convert ▸ PNG** — shown on images only |
| Nemo | Cinnamon | `~/.local/share/nemo/actions/` + `~/.config/nemo/actions/actions-tree.json` | **Convert ▸ PNG** — shown on images only |
| Caja | MATE | `~/.config/caja/scripts/` | **Scripts ▸ Convert ▸ PNG** |

Thunar's `uca.xml` and Nemo's `actions-tree.json` are edited in place: your own
custom actions and menu layout are preserved, and `./uninstall.sh` removes only
the entries this project added. Nemo shows actions flat unless that layout file
groups them, which is why it is touched at all.

## Languages

Menu strings live in [`i18n/menu.tsv`](i18n/menu.tsv) — one tab-separated row
per language. Adding one means adding one row; nothing else changes.

Two mechanisms are used, because file managers differ. Dolphin's `.desktop` and
Nemo's `.nemo_action` carry *every* language at once as `Key[lang]=` lines, so a
system-wide package serves every user on the machine whatever their locale. The
Nautilus extension picks its language at runtime from the environment. Thunar's
`uca.xml` and the Nautilus/Caja *Scripts* folders have no per-language
mechanism, so they get the language of whoever ran `install.sh` — the installer
prints which one it used, and `--lang` overrides it when your desktop runs in
one language but you want the menu in another. Re-running with a different
language replaces the old entries rather than leaving both behind.

## Options

```sh
./install.sh --formats png,jpg          # only offer these two
./install.sh --lang fr                  # menu in French on an English desktop
./install.sh --only nautilus            # skip the other file managers
./install.sh --no-restart               # don't restart file managers
./uninstall.sh                          # remove everything
```

Any format ImageMagick can write works with `--formats` (`tiff`, `gif`, `bmp`,
`heic`, …). AVIF and HEIC need the matching ImageMagick delegates, which some
distributions ship in a separate package.

## Behaviour

- **Nothing is ever overwritten.** If `photo.png` exists you get `photo-1.png`.
  This holds for documents too, including several files that share a name in
  different folders — LibreOffice writes all its output to one directory, so
  they are converted in rounds rather than overwriting each other.
- **The original is kept.** This converts, it does not replace.
- **Multiple selection works** — select 30 files, convert them all at once.
- **JPG gets a white background**, since JPEG has no transparency.
- A desktop notification reports how many files succeeded, and names the ones
  that failed.
- **Long conversions show progress**, as a bar on the terminal or a notification
  that updates in place. Nothing appears for the first second, so quick
  conversions stay silent. Image percentages are real, read from ImageMagick;
  LibreOffice reports nothing while it works, so a lone document gets an
  indeterminate bar and a batch is tracked by file. GNOME Shell's notification
  daemon cannot draw progress bars, so the bar is text; daemons that support the
  `value` hint, Plasma's among them, draw a real one.
- **Document conversion uses a throwaway LibreOffice profile**, so it works
  while LibreOffice is open and never disturbs the running instance.
- **A mixed selection is routed per file**: images to ImageMagick, documents to
  LibreOffice, in one command.

## Command line

The same converter is installed as a normal CLI, with a man page:

```sh
file-convert png photo.webp     # images, via ImageMagick
file-convert pdf rapport.docx   # documents, via LibreOffice
file-convert jpg *.png
man file-convert
```

## Packaging

Distribution packagers should use the `Makefile` rather than `install.sh`,
which is a per-user installer and restarts file managers:

```sh
make install DESTDIR=/tmp/pkgroot PREFIX=/usr
make uninstall DESTDIR=/tmp/pkgroot PREFIX=/usr
```

Ready-made recipes for AUR, COPR, the KDE Store and Cinnamon Spices live in
[`packaging/`](packaging/README.md), each with how it was verified.

`DESTDIR` only says where to stage the files; the paths baked into the
generated menu entries always use `PREFIX`. Overridable variables: `PREFIX`,
`BINDIR`, `DATADIR`, `MANDIR`, `FORMATS`, `NAUTILUS_ABI` (the Nautilus GIR
version to target, `4.0` by default; use `3.0` for GNOME 42 and older).

A package can only ship the Dolphin, Nemo and Nautilus-extension entries:
Thunar's `uca.xml` and the Nautilus/Caja *Scripts* folders are per-user files
with no system-wide drop-in, so users of those run `./install.sh`.

## Tests

```sh
make check     # or: ./tests/smoke.sh
make lint      # shellcheck + python syntax
```

The tests convert real generated images and check the output type, the
no-overwrite suffixing, multi-file handling, and clean failure on a corrupt
input. CI additionally exercises both install paths end to end.

Note: `desktop-file-validate` reports errors on the Dolphin service menu
(`Name` missing, `MimeType`/`Actions` "invalid for Type=Service"). That is
expected — `Type=Service` is a KDE extension the freedesktop validator does not
model, and KDE's own example service menu has the same shape.

## How it works

`bin/file-convert` is the only thing that does real work — one small shell
script that picks ImageMagick or LibreOffice from what the source file is. Each file manager gets a thin generated entry
(a `.desktop` action, a `.nemo_action`, an XML block, or an executable script)
that calls it with a target format and the selected paths. Adding another file
manager means adding one template plus an `emit_*` helper in `tools/lib.sh`,
shared by the per-user installer and the packaging path.

## License

MIT — see [LICENSE](LICENSE).
