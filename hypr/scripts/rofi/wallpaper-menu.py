#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from config import WALLPAPERS_DIR, WALLPAPERS_OUT_DIR, WALLPAPERS_THUMB_DIR, ROFI_THEME_WALLPAPER

HELPERS_DIR = Path(__file__).parent.parent / "helpers"
EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}

paths = sorted(p for p in WALLPAPERS_DIR.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS)

if not paths:
    subprocess.run(["notify-send", "Wallpaper", f"No images found in {WALLPAPERS_DIR}"])
    sys.exit(1)

subprocess.run([sys.executable, str(HELPERS_DIR / "prepare-wallpaper-files.py")], capture_output=True)

entries = b"".join(
    f"{p.stem}\x00icon\x1f{WALLPAPERS_THUMB_DIR / (p.stem + '.png')}\n".encode()
    for p in paths
)

result = subprocess.run(
    ["rofi", "-dmenu", "-p", "Wallpaper", "-show-icons",
     "-theme", str(ROFI_THEME_WALLPAPER), "-format", "i"],
    input=entries,
    capture_output=True,
)
if result.returncode != 0:
    sys.exit(0)

idx = int(result.stdout.strip())
src = paths[idx]
dest = WALLPAPERS_OUT_DIR / f"{src.stem}.png"
image = dest if dest.exists() else src

subprocess.run(["matugen", "image", str(image), "--prefer", "saturation"])
