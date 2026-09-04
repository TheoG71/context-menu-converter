# context-menu-converter

A per-user "Convert to …" context-menu integration for Linux file managers, plus
the `file-convert` CLI that does the actual work. Pure Bash + a little Python; no
build step, no dependencies to install for development.

## Layout

| Path | What it is |
|---|---|
| `bin/file-convert` | The only thing that converts. Routes to ImageMagick (images) or LibreOffice (documents) based on the source file. Carries `VERSION`. |
| `tools/lib.sh` | Shared generator: turns `integrations/` templates into real menu files. Sourced by `install.sh` and `tools/stage.sh`. |
| `get.sh` | One-line bootstrap: fetches the release tarball to a temp dir, runs `install.sh` (or `uninstall.sh`) from it, cleans up. POSIX `sh` so it can be piped; must not `exec`, or the cleanup trap never fires. |
| `install.sh` / `uninstall.sh` | Per-user installer into `$HOME` (also covers Thunar and the Scripts fallbacks). |
| `Makefile` + `tools/stage.sh` | System-wide packaging path (`DESTDIR`/`PREFIX`). Packagers use this, never `install.sh`. |
| `integrations/<fm>/` | One template per file manager. |
| `i18n/menu.tsv` | One tab-separated row per language: `lang`, submenu label, item label, tooltip. |
| `packaging/` | AUR, RPM/COPR, KDE Store, Cinnamon Spices recipes. |
| `tests/smoke.sh` | Converts real generated images and checks output type, suffixing, multi-file, failure paths. |

## Conventions that matter here

- **`tools/lib.sh` has a contract with its callers.** They must set `LIB_SRC`,
  `BIN`, `FORMATS` and `LIB_I18N` before sourcing it. The `# shellcheck disable`
  comments about those variables are deliberate — don't "fix" them.
- **Two install paths, one generator.** Any new file manager means a template in
  `integrations/` plus an `emit_*` helper in `tools/lib.sh`, wired into both
  `install.sh` and `tools/stage.sh`.
- **`DESTDIR` is staging only.** Paths baked into generated menu entries always
  use `PREFIX`.
- **Never overwrite user files.** Thunar's `uca.xml` and Nemo's
  `actions-tree.json` are edited in place; `uninstall.sh` removes only the
  entries this project added. Converted output never overwrites either —
  `photo.png` becomes `photo-1.png`.
- **Uninstall must be locale-independent.** Entries installed in one language get
  removed from a session running in another (`all_labels` exists for this), and
  the removal lists cover names from earlier versions so upgrades leave nothing
  behind.
- **Adding a language is one row in `i18n/menu.tsv`.** Nothing else changes.
- **Version lives in three places on a release**: `VERSION` in `bin/file-convert`,
  `CHANGELOG.md`, and the `packaging/` recipes (including checksums).

## Checks

```sh
make check    # ./tests/smoke.sh — needs ImageMagick with webp
make lint     # shellcheck -x + python3 -m py_compile
```

`make lint` needs the shellcheck version pinned in `.github/workflows/ci.yml`
(`SHELLCHECK_VERSION`); distro versions report different findings, which has
already broken CI more than once. Keep the file list in the `lint` target and in
the workflow in step with each other.

CI additionally exercises both install paths end to end, the localisation
behaviour, and the packaging archives. `XDG_DATA_HOME`/`XDG_CONFIG_HOME`/
`XDG_BIN_HOME` are how the tests install into a throwaway home — use the same
trick when trying `install.sh` by hand, never a bare run that touches the real
`$HOME`.

`desktop-file-validate` reporting errors on the Dolphin service menu is expected:
`Type=Service` is a KDE extension the freedesktop validator does not model.
