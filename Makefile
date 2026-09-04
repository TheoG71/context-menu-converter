# System-wide install, for distribution packagers.
# End users should run ./install.sh instead — it installs into $HOME and
# covers Thunar and the Caja/Nautilus script fallbacks, which have no
# system-wide drop-in location.
#
#   make install DESTDIR=/tmp/pkgroot PREFIX=/usr

PREFIX       ?= /usr/local
BINDIR       ?= $(PREFIX)/bin
DATADIR      ?= $(PREFIX)/share
MANDIR       ?= $(DATADIR)/man
DESTDIR      ?=
NAUTILUS_ABI ?= 4.1
FORMATS      ?= png jpg webp avif

INSTALL ?= install

.PHONY: all install uninstall check lint clean dist-kde dist-spice

all:
	@echo "Nothing to build. Run 'make install' (packagers) or ./install.sh (users)."

install:
	$(INSTALL) -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	$(INSTALL) -m 755 bin/file-convert $(DESTDIR)$(BINDIR)/file-convert
	$(INSTALL) -m 644 man/file-convert.1 $(DESTDIR)$(MANDIR)/man1/file-convert.1
	./tools/stage.sh "$(DESTDIR)" "$(PREFIX)" "$(NAUTILUS_ABI)" $(FORMATS)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/file-convert
	rm -f $(DESTDIR)$(MANDIR)/man1/file-convert.1
	rm -f $(DESTDIR)$(DATADIR)/nautilus-python/extensions/file-convert.py
	rm -f $(DESTDIR)$(DATADIR)/kio/servicemenus/file-convert-*.desktop
	rm -f $(DESTDIR)$(DATADIR)/nemo/actions/file-convert-*.nemo_action

check:
	./tests/smoke.sh

# Keep this list in step with .github/workflows/ci.yml, which pins the
# shellcheck version so local and CI agree on what counts as a finding.
lint:
	shellcheck -x bin/file-convert get.sh install.sh uninstall.sh tests/smoke.sh tools/*.sh packaging/*/*.sh
	python3 -m py_compile integrations/thunar/uca-edit.py
	@echo "note: desktop-file-validate reports errors on KDE 'Type=Service' menus; that is expected."

dist-kde:
	./packaging/kde-store/build-tarball.sh

dist-spice:
	./packaging/cinnamon-spices/build-spice.sh

clean:
	rm -rf dist integrations/thunar/__pycache__
