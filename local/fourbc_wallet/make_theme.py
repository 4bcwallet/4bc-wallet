#!/usr/bin/env python3
# Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
# Added 23 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
#
# Packs the 4bc theme (local/fourbc_wallet/theme/: theme.json and assets/) into
# asset_sources/default_themes/fourbc_wallet/light.zip, the file the app installs
# as its built-in theme on first start.
#
# Why the id is "light": the app's code installs and falls back to the theme whose id
# is "light" (lib/themes/theme_service.dart, lib/main.dart, lib/utilities/prefs.dart).
# 4bc Wallet has one look, so our theme takes that slot and theme selection is switched
# off in configure_fourbc_wallet.sh. Its brightness is "dark": the ground is grey.
#
# Before packing it checks our theme against upstream's dark theme of the same tag:
# the same colour keys, the same asset keys, the same version, and every picture the
# theme names present. A new upstream release that adds a key therefore stops here,
# with the key's name, instead of producing an app that fails to start.
#
# The zip is deterministic (fixed dates, sorted names): the same sources give the same bytes.
#
# Usage: python3 local/fourbc_wallet/make_theme.py     (from anywhere)

import io
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "local" / "fourbc_wallet" / "theme"
UPSTREAM = ROOT / "asset_sources" / "default_themes" / "stack_duo" / "dark.zip"
OUT = ROOT / "asset_sources" / "default_themes" / "fourbc_wallet" / "light.zip"


def die(msg):
    print(f"make_theme: {msg}", file=sys.stderr)
    sys.exit(1)


def flat_keys(d, prefix=""):
    keys = set()
    for k, v in d.items():
        if isinstance(v, dict):
            keys |= flat_keys(v, f"{prefix}{k}.")
        else:
            keys.add(f"{prefix}{k}")
    return keys


def flat_values(d):
    for v in d.values():
        if isinstance(v, dict):
            yield from flat_values(v)
        else:
            yield v


def main():
    ours = json.loads((SRC / "theme.json").read_text())
    with zipfile.ZipFile(UPSTREAM) as z:
        theirs = json.loads(z.read("theme.json"))

    for part in ("colors", "assets"):
        a, b = flat_keys(ours[part]), flat_keys(theirs[part])
        if a != b:
            die(f"{part} differ from upstream's dark theme: missing {sorted(b - a)}, extra {sorted(a - b)}")
    if set(ours) != set(theirs):
        die(f"top-level keys differ from upstream: {sorted(set(ours) ^ set(theirs))}")
    if ours["version"] != theirs["version"]:
        die(f"version {ours['version']} is not upstream's {theirs['version']}: read what changed, then set it")
    if ours["id"] != "light" or ours["brightness"] not in ("light", "dark"):
        die('id must be "light" and brightness "light" or "dark"')

    for k, v in ours["colors"].items():
        if isinstance(v, str) and not (v.startswith("0x") and len(v) == 10):
            die(f"colour {k} is not of the form 0xAARRGGBB: {v}")

    files = sorted(p for p in (SRC / "assets").rglob("*") if p.is_file() and p.name != ".DS_Store")
    present = {str(p.relative_to(SRC / "assets")) for p in files}
    for rel in set(flat_values(ours["assets"])):
        if rel not in present:
            die(f"the theme names a picture that is not in theme/assets: {rel}")

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        def add(name, data):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, data)

        add("theme.json", (SRC / "theme.json").read_bytes())
        for p in files:
            add("assets/" + str(p.relative_to(SRC / "assets")), p.read_bytes())

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(buf.getvalue())
    print(f"make_theme: wrote {OUT.relative_to(ROOT)} ({len(buf.getvalue())} bytes, {len(files)} pictures, "
          f"{len(flat_keys(ours['colors']))} colours)")


if __name__ == "__main__":
    main()
