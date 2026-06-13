#!/usr/bin/env python3

import hashlib
import json
import subprocess
import sys
from pathlib import Path

EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}


def load_config() -> dict[str, str]:
    config_path = Path(__file__).parent.parent / "config.sh"
    result = subprocess.run(
        ["bash", "-c", f'. "{config_path}" && env -0'],
        capture_output=True, text=True,
    )
    env = {}
    for entry in result.stdout.split("\0"):
        k, _, v = entry.partition("=")
        if k:
            env[k] = v
    return env


def get_resolution() -> str | None:
    try:
        result = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True, text=True, check=True,
        )
        monitors = json.loads(result.stdout)
        focused = next((m for m in monitors if m.get("focused")), None)
        if focused:
            return f"{focused['width']}x{focused['height']}"
    except Exception:
        pass
    return None


def thumb_hash(path: Path) -> str:
    # Match bash: md5sum <<< "$path" adds a trailing newline
    return hashlib.md5((str(path) + "\n").encode()).hexdigest()


def magick(*args: str) -> None:
    subprocess.run(["magick", *args], check=True)


def main() -> None:
    config = load_config()
    wallpapers_dir = Path(config["WALLPAPERS_DIR"])
    out_dir = Path(config["WALLPAPERS_OUT_DIR"])
    thumb_dir = Path(config["WALLPAPERS_THUMB_DIR"])

    out_dir.mkdir(parents=True, exist_ok=True)
    thumb_dir.mkdir(parents=True, exist_ok=True)

    resolution = get_resolution()
    if not resolution:
        print("Warning: could not determine monitor resolution, skipping resize", file=sys.stderr)

    sources = sorted(p for p in wallpapers_dir.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS)

    valid_stems = {p.stem for p in sources}
    valid_thumb_hashes = {thumb_hash(p) for p in sources}

    for dest in out_dir.glob("*.png"):
        if dest.stem not in valid_stems:
            print(f"Removing stale: {dest.name}")
            dest.unlink()

    for thumb in thumb_dir.glob("*.png"):
        if thumb.stem not in valid_thumb_hashes:
            thumb.unlink()

    for src in sources:
        thumb = thumb_dir / f"{thumb_hash(src)}.png"

        if resolution:
            dest = out_dir / f"{src.stem}.png"
            if not dest.exists() or dest.stat().st_mtime < src.stat().st_mtime:
                print(f"Converting: {src.name}")
                magick(str(src), "-resize", f"{resolution}^", "-gravity", "center", "-extent", resolution, str(dest))

        if not thumb.exists() or thumb.stat().st_mtime < src.stat().st_mtime:
            print(f"Thumbnail: {src.name}")
            magick(str(src), "-thumbnail", "256x256^", "-gravity", "center", "-extent", "256x256", str(thumb))


if __name__ == "__main__":
    main()
