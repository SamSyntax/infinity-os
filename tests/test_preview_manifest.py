#!/usr/bin/env python3
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MANIFEST = REPO / "installation/preview-packages.official.txt"
REQUIRED = {
    "hyprland",
    "quickshell",
    "ghostty",
    "hypridle",
    "hyprlock",
    "xdg-desktop-portal",
    "xdg-desktop-portal-hyprland",
    "xdg-desktop-portal-gtk",
    "qt6-wayland",
    "ttf-ibm-plex",
    "noto-fonts",
}


def main():
    pattern = re.compile(r"^[a-z0-9@._+-]+$")
    packages = []
    for line_no, line in enumerate(MANIFEST.read_text(encoding="utf-8").splitlines(), 1):
        item = line.split("#", 1)[0].strip()
        if not item:
            continue
        if not pattern.fullmatch(item):
            raise SystemExit(f"invalid preview package token at line {line_no}: {item!r}")
        packages.append(item)
    missing = REQUIRED - set(packages)
    if missing:
        raise SystemExit(f"preview manifest missing required packages: {sorted(missing)}")
    if len(packages) != len(set(packages)):
        raise SystemExit("preview manifest contains duplicates")
    print("ok: preview package manifest tokens")


if __name__ == "__main__":
    main()
