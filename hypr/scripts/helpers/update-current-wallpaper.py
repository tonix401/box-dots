#!/usr/bin/env python3
"""
Called by matugen after setting the wallpaper.
Writes the current-wallpaper files used by rofi and other tools.

Usage: update-current-wallpaper.py <image-path>
"""

import shutil
import sys
from pathlib import Path

CACHE_DIR = Path.home() / ".cache/box-dots"
THUMB_DIR = CACHE_DIR / "wallpaper-thumbnails"


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("Usage: update-current-wallpaper.py <image-path>")

    src = Path(sys.argv[1])
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    shutil.copy2(src, CACHE_DIR / "current/wallpaper.png")

    thumb = THUMB_DIR / f"{src.stem}.png"
    if thumb.exists():
        shutil.copy2(thumb, CACHE_DIR / "current/wallpaper-square.png")

    (CACHE_DIR / "current/wallpaper").write_text(str(src) + "\n")


if __name__ == "__main__":
    main()
