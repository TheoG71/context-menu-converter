# context-menu-converter — Nautilus extension (needs nautilus-python)
# Installed to ~/.local/share/nautilus-python/extensions/ by install.sh
import os
import subprocess

import gi

# The version detected at install time comes first; the rest let the extension
# survive a Nautilus upgrade that bumps the GIR version.
for _version in ("@NAUTILUS_ABI@", "4.2", "4.1", "4.0", "3.0"):
    try:
        gi.require_version("Nautilus", _version)
        break
    except ValueError:
        continue

from gi.repository import GObject, Nautilus  # noqa: E402

BIN = "@BIN@"
# profile -> (accepted MIME types, target formats)
PROFILES = @PROFILES_PY@
# lang -> (submenu label, item tooltip with a %s for the format)
TRANSLATIONS = @TRANSLATIONS@


def _strings():
    """Menu strings for the session's language, falling back to English."""
    for var in ("LC_ALL", "LC_MESSAGES", "LANG"):
        value = os.environ.get(var)
        if not value:
            continue
        lang = value.split(".")[0].split("@")[0]
        for key in (lang, lang.split("_")[0]):
            if key in TRANSLATIONS:
                return TRANSLATIONS[key]
    return TRANSLATIONS["en"]


def _formats_for(files):
    """Target formats for this selection, or None if it is not one we handle.

    A mixed selection offers nothing: the formats that suit an image are not
    the ones that suit a document, and silently converting only half of what
    was selected would be worse than showing no menu at all.
    """
    mimes = set()
    for f in files:
        if f.get_uri_scheme() != "file":
            return None
        mimes.add(f.get_mime_type())

    for accepted, formats in PROFILES.values():
        if mimes <= accepted:
            return formats
    return None


class ConvertHere(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        if not files:
            return []
        formats = _formats_for(files)
        if not formats:
            return []

        submenu_label, tooltip = _strings()
        top = Nautilus.MenuItem(name="ConvertHere::Top", label=submenu_label)
        submenu = Nautilus.Menu()
        top.set_submenu(submenu)

        for fmt in formats:
            item = Nautilus.MenuItem(
                name="ConvertHere::%s" % fmt,
                label=fmt.upper(),
                tip=tooltip % fmt.upper(),
            )
            item.connect("activate", self._convert, fmt, files)
            submenu.append_item(item)
        return [top]

    def _convert(self, menu, fmt, files):
        paths = [f.get_location().get_path() for f in files]
        subprocess.Popen([BIN, fmt] + [p for p in paths if p])
