# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-09-04

First release.

### Added

- `file-convert`, a CLI that converts images through ImageMagick and office
  documents to PDF through LibreOffice, choosing the engine from what the source
  file actually is rather than from its name.
- Context-menu entries for five file managers — Nautilus (GNOME), Dolphin (KDE),
  Thunar (XFCE), Nemo (Cinnamon) and Caja (MATE) — generated for each from a
  single shared library, so the menu offers only the formats that suit the file
  that was clicked.
- Menu strings in 32 languages, with English as the fallback. Dolphin and Nemo
  entries carry every language at once; the Nautilus extension picks one at
  runtime; Thunar and the Scripts folders take the language of whoever ran the
  installer, overridable with `--lang`.
- `install.sh` / `uninstall.sh`, a per-user installer that needs no root, edits
  Thunar's `uca.xml` and Nemo's `actions-tree.json` in place without disturbing
  the user's own actions, and removes only what it added.
- `get.sh`, a one-line installer: `curl -fsSL …/get.sh | sh`.
- Progress reporting for slow conversions, as a terminal bar or a notification
  that updates in place, staying silent for the first second so quick
  conversions do not flash a notification.
- A `Makefile` for distribution packagers, with `DESTDIR`/`PREFIX` staging, plus
  packaging recipes for AUR, COPR, the KDE Store and Cinnamon Spices.
- A man page, a smoke-test suite, and CI that exercises both install paths, the
  localisation behaviour and every packaging artifact end to end.

[1.0.0]: https://github.com/TheoG71/context-menu-converter/releases/tag/v1.0.0
