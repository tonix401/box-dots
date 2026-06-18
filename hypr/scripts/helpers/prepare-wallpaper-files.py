#!/usr/bin/env python3

import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

try:
    import pyvips
    HAS_PYVIPS = True
except ImportError:
    HAS_PYVIPS = False

sys.path.insert(0, str(Path(__file__).parent.parent))
from config import WALLPAPERS_DIR, WALLPAPERS_OUT_DIR, WALLPAPERS_THUMB_DIR

EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}


def get_resolution() -> tuple[int, int] | None:
    try:
        result = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True, text=True, check=True,
        )
        monitors = json.loads(result.stdout)
        focused = next((m for m in monitors if m.get("focused")), None)
        if focused:
            return focused["width"], focused["height"]
    except Exception:
        pass
    return None


def main() -> None:
    out_dir = WALLPAPERS_OUT_DIR
    thumb_dir = WALLPAPERS_THUMB_DIR

    out_dir.mkdir(parents=True, exist_ok=True)
    thumb_dir.mkdir(parents=True, exist_ok=True)

    resolution = get_resolution()
    if not resolution:
        print("Warning: could not determine monitor resolution, skipping resize", file=sys.stderr)

    sources = sorted(p for p in WALLPAPERS_DIR.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS)

    valid_stems = {p.stem for p in sources}

    for dest in out_dir.glob("*.png"):
        if dest.stem not in valid_stems:
            print(f"Removing stale: {dest.name}")
            dest.unlink()

    for thumb in thumb_dir.glob("*.png"):
        if thumb.stem not in valid_stems:
            thumb.unlink()

    def vips_resize(src: Path, dest: Path, w: int, h: int) -> None:
        img = pyvips.Image.thumbnail(str(src), w, height=h, crop=pyvips.enums.Interesting.CENTRE)
        img.write_to_file(str(dest))

    def magick_resize(src: Path, dest: Path, w: int, h: int) -> None:
        res = f"{w}x{h}"
        subprocess.run(
            ["magick", str(src), "-resize", f"{res}^", "-gravity", "center", "-extent", res, str(dest)],
            check=True,
        )

    resize = vips_resize if HAS_PYVIPS else magick_resize

    def process(src: Path) -> list[str]:
        messages = []
        thumb = thumb_dir / f"{src.stem}.png"

        if resolution:
            w, h = resolution
            dest = out_dir / f"{src.stem}.png"
            if not dest.exists() or dest.stat().st_mtime < src.stat().st_mtime:
                messages.append(f"Converting: {src.name}")
                resize(src, dest, w, h)

        if not thumb.exists() or thumb.stat().st_mtime < src.stat().st_mtime:
            messages.append(f"Thumbnail: {src.name}")
            resize(src, thumb, 256, 256)

        return messages

    with ThreadPoolExecutor() as pool:
        futures = {pool.submit(process, src): src for src in sources}
        for future in as_completed(futures):
            try:
                for msg in future.result():
                    print(msg)
            except Exception as e:
                print(f"Error processing {futures[future].name}: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
