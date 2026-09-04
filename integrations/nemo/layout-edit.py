#!/usr/bin/env python3
"""Group the image-convert actions under a submenu in Nemo's action layout.

Usage: layout-edit.py install <submenu-label> <action-basename>...
       layout-edit.py uninstall

Nemo shows actions flat unless ~/.config/nemo/actions/actions-tree.json says
otherwise. That file belongs to Nemo's layout editor, so this only adds or
removes one submenu and leaves every other entry untouched. Actions missing
from the tree still show up, so users who never opened the editor keep their
other actions.
"""
import json
import os
import sys

TREE = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "nemo", "actions", "actions-tree.json",
)
# Legacy (non-spice) actions are identified by file name plus this suffix.
SUFFIX = "@untracked"
# Action files installed by any version of this project.
PREFIXES = ("file-convert-", "image-convert-")


def load():
    if os.path.exists(TREE) and os.path.getsize(TREE) > 0:
        try:
            with open(TREE, encoding="utf-8") as fh:
                data = json.load(fh)
            if isinstance(data.get("toplevel"), list):
                return data
        except (ValueError, OSError):
            # A malformed layout makes Nemo fall back to a flat list; replacing
            # it is no worse than what the user already has.
            pass
    return {"toplevel": []}


def is_ours(entry):
    if entry.get("type") == "action":
        return str(entry.get("uuid", "")).startswith(PREFIXES)
    if entry.get("type") == "submenu":
        children = entry.get("children") or []
        return bool(children) and all(is_ours(child) for child in children)
    return False


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    data = load()
    data["toplevel"] = [e for e in data["toplevel"] if not is_ours(e)]

    if mode == "install":
        submenu, names = sys.argv[2], sys.argv[3:]
        children = [
            {
                "uuid": "%s.nemo_action%s" % (name, SUFFIX),
                "type": "action",
                "position": i,
                "user-label": name.rsplit("-", 1)[-1].upper(),
                "user-icon": None,
            }
            for i, name in enumerate(names)
        ]
        data["toplevel"].append({
            "uuid": submenu,
            "type": "submenu",
            "position": len(data["toplevel"]),
            "user-label": None,
            "user-icon": None,
            "children": children,
        })
    elif mode != "uninstall":
        sys.exit(__doc__)

    for i, entry in enumerate(data["toplevel"]):
        entry["position"] = i

    os.makedirs(os.path.dirname(TREE), exist_ok=True)
    tmp = TREE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, TREE)


if __name__ == "__main__":
    main()
