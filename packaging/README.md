# Packaging and distribution

Four channels, each with a different shape. Everything here was built and run
before being committed — see *Verified* under each section.

| Channel | Artifact | Status |
|---|---|---|
| [AUR](#aur-arch) | `aur/PKGBUILD`, `aur/.SRCINFO` | builds, ready to publish |
| [COPR](#copr-fedora) | `rpm/context-menu-converter.spec` | builds, ready to publish |
| [KDE Store](#kde-store-dolphin) | `kde-store/build-tarball.sh` | archive builds and round-trips |
| [Cinnamon Spices](#cinnamon-spices-nemo) | `cinnamon-spices/build-spice.sh` | passes `validate-spice`, **read the caveat** |

> **Two ways the checksum moves under you.** GitHub rebuilds tag archives with
> the repository's current name, so renaming the repository changes the tarball
> and its `sha256` even though the tag does not. And a re-pushed tag keeps
> serving the previous archive from cache for about a minute — wait, re-fetch,
> and confirm the content before trusting the checksum you computed.

All of them consume the release tarball or the `Makefile`, so bumping a version
means: update `CHANGELOG.md`, tag, publish the release, then update `pkgver` /
`Version` and the `sha256` in the two package recipes.

---

## AUR (Arch)

```sh
git clone ssh://aur@aur.archlinux.org/context-menu-converter.git aur-repo
cp packaging/aur/PKGBUILD packaging/aur/.SRCINFO aur-repo/
cd aur-repo && git add -A && git commit -m "Initial import: 1.0.0" && git push
```

Publishing needs an AUR account with your SSH public key registered at
<https://aur.archlinux.org/account/>.

**Verified:** `makepkg` in an `archlinux:base-devel` container — sources fetched
and checksummed, `check()` ran the smoke tests, package produced with the 10
expected files. The committed `.SRCINFO` is byte-identical to
`makepkg --printsrcinfo`.

## COPR (Fedora)

```sh
copr-cli create context-menu-converter --chroot fedora-rawhide-x86_64
copr-cli build context-menu-converter packaging/rpm/context-menu-converter.spec
```

Or point a COPR project at this Git repo with the spec path
`packaging/rpm/context-menu-converter.spec` and let it rebuild on push.

**Verified:** `rpmbuild -ba` in a `fedora:latest` container — builds with no
warnings, `rpmlint` reports only a spelling false positive on "Thunar", and the
resulting RPM installs and converts an image for real. `%undefine
__brp_python_bytecompile` is required: the Nautilus extension lives in
`%{_datadir}` and byte-compiling it would leave an unpackaged `__pycache__`.

## KDE Store (Dolphin)

```sh
packaging/kde-store/build-tarball.sh      # writes dist/…-kde.tar.gz
```

Upload it to <https://store.kde.org> under **Dolphin Service Menus**. Users then
get it from Dolphin ▸ Configure ▸ Context Menu ▸ *Download New Services*.

KNewStuff runs `install.sh` from the archive root on install and `uninstall.sh`
on removal, which is why the archive has no wrapper directory and why the
project's own scripts are shipped as-is: they already install into
`~/.local/share/kio/servicemenus`, bake absolute paths into `Exec=`, mark the
`.desktop` executable (KDE ignores it otherwise) and never need root.

**Verified:** the archive was extracted into a throwaway `XDG_DATA_HOME` and put
through the full KNewStuff cycle — `install.sh` placed a mode-755 service menu
with an absolute `Exec=`, and `uninstall.sh` removed everything.

## Cinnamon Spices (Nemo)

```sh
packaging/cinnamon-spices/build-spice.sh  # writes dist/cinnamon-spices/convert-to-png@TheoG71/
```

Submit by pull request to
[linuxmint/cinnamon-spices-actions](https://github.com/linuxmint/cinnamon-spices-actions):
copy the generated `convert-to-png@TheoG71/` directory to the repository root,
run `./validate-spice convert-to-png@TheoG71`, and open the PR.

**Caveat — read before submitting.** A spice ships exactly one `[Nemo Action]`,
so the per-format submenu this project installs everywhere else cannot be
expressed as a spice. More importantly,
[`convert-image-format@el-amine-404`](https://cinnamon-spices.linuxmint.com/actions)
already exists and covers image conversion, PDF↔image, and 15 formats through a
zenity dialog. What this spice offers that the existing one does not is a
*dialog-free* one-click conversion to PNG — that is the only non-redundant thing
to submit, and reviewers may still consider it redundant. It is built and valid;
whether to open the PR is a judgement call.

**Verified:** the official `validate-spice` from the upstream repository, run
against the generated tree in a container with its real dependencies
(`python3-gobject`, `python3-pillow`, `gettext`): *No errors found.*
