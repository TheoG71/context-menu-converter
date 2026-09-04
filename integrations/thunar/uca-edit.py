#!/usr/bin/env python3
"""Add or remove image-convert actions in Thunar's ~/.config/Thunar/uca.xml.

Usage: uca-edit.py install <bin> <submenu-label> <profile>:<patterns>:<fmt,fmt> ...
       uca-edit.py uninstall

uca.xml has no per-language keys, so the submenu label is written in the
language of whoever runs install.sh.
"""
import os
import sys
import xml.etree.ElementTree as ET

UCA = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "Thunar",
    "uca.xml",
)
# Actions installed by any version of this project start with one of these.
PREFIXES = ("file-convert-", "image-convert-")


def load():
    if os.path.exists(UCA) and os.path.getsize(UCA) > 0:
        try:
            return ET.parse(UCA).getroot()
        except ET.ParseError:
            sys.exit("uca.xml is malformed; fix or remove it and re-run")
    return ET.Element("actions")


def drop_ours(root):
    for action in list(root.findall("action")):
        uid = action.findtext("unique-id") or ""
        if uid.startswith(PREFIXES):
            root.remove(action)


def save(root):
    os.makedirs(os.path.dirname(UCA), exist_ok=True)
    ET.indent(root, space="  ")
    tree = ET.ElementTree(root)
    tmp = UCA + ".tmp"
    tree.write(tmp, encoding="UTF-8", xml_declaration=True)
    os.replace(tmp, UCA)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    root = load()
    drop_ours(root)

    if mode == "install":
        binary, submenu, specs = sys.argv[2], sys.argv[3], sys.argv[4:]
        for spec in specs:
            profile, patterns, formats = spec.split(":", 2)
            for fmt in formats.split(","):
                action = ET.SubElement(root, "action")
                for tag, text in (
                    ("icon", "document-save"),
                    ("name", fmt.upper()),
                    ("submenu", submenu),
                    ("unique-id", "file-convert-%s-%s" % (profile, fmt)),
                    ("command", '"%s" %s %%F' % (binary, fmt)),
                    ("description", "Convert the selection to " + fmt.upper()),
                    ("patterns", patterns),
                ):
                    ET.SubElement(action, tag).text = text
                ET.SubElement(action, "other-files")
    elif mode != "uninstall":
        sys.exit(__doc__)

    save(root)


if __name__ == "__main__":
    main()
