#!/usr/bin/env python3

import colorsys
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
from config import (
    WALLPAPERS_DIR,
    WALLPAPERS_OUT_DIR,
    WALLPAPERS_PALETTE_FILE,
    WALLPAPERS_PREVIEW_DIR,
    WALLPAPERS_THUMB_DIR,
)

EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}
# Width of the wallpaper menu's grid tiles (QML sourceSize.width); height follows the monitor aspect.
PREVIEW_WIDTH = 480

# Hue bands (degrees) used to tag each wallpaper with a color "direction" for the menu's filter chips.
# Order matters: the first band whose range contains the hue wins.
HUE_BANDS = [
    ("red", 345, 360),
    ("red", 0, 15),
    ("orange", 15, 45),
    ("yellow", 45, 70),
    ("green", 70, 170),
    ("cyan", 170, 200),
    ("blue", 200, 255),
    ("purple", 255, 290),
    ("pink", 290, 345),
]


def hex_to_rgb(hex_color: str) -> tuple[float, float, float]:
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return r, g, b


def direction_of(hex_color: str) -> str:
    r, g, b = hex_to_rgb(hex_color)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.12:
        return "neutral"
    degrees = h * 360
    for name, lo, hi in HUE_BANDS:
        if lo <= degrees < hi:
            return name
    return "neutral"


def extract_palette(image: Path) -> dict | None:
    """Run matugen as a dry run to get the colors it would theme with, without touching anything."""
    try:
        result = subprocess.run(
            ["matugen", "image", str(image), "--dry-run", "-j", "hex", "--prefer", "saturation", "-q"],
            capture_output=True, text=True, check=True,
        )
        data = json.loads(result.stdout)
        colors = data["colors"]
        primary = colors["primary"]["dark"]["color"]
        secondary = colors["secondary"]["dark"]["color"]
        tertiary = colors["tertiary"]["dark"]["color"]
        return {
            "colors": [primary, secondary, tertiary],
            "direction": direction_of(primary),
        }
    except Exception as e:
        print(f"Error extracting palette for {image.name}: {e}", file=sys.stderr)
        return None


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
    preview_dir = WALLPAPERS_PREVIEW_DIR

    for d in (out_dir, thumb_dir, preview_dir):
        d.mkdir(parents=True, exist_ok=True)

    resolution = get_resolution()
    if not resolution:
        print("Warning: could not determine monitor resolution, skipping resize", file=sys.stderr)

    sources = sorted(p for p in WALLPAPERS_DIR.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS)

    valid_stems = {p.stem for p in sources}

    for dest in out_dir.glob("*.png"):
        if dest.stem not in valid_stems:
            print(f"Removing stale: {dest.name}")
            dest.unlink()

    for small in (*thumb_dir.glob("*.png"), *preview_dir.glob("*.png")):
        if small.stem not in valid_stems:
            small.unlink()

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

            # monitor-shaped and small, so the menu grid decodes it in ~2ms instead of the full-size copy's ~60ms
            preview = preview_dir / f"{src.stem}.png"
            if not preview.exists() or preview.stat().st_mtime < src.stat().st_mtime:
                messages.append(f"Preview: {src.name}")
                resize(src, preview, PREVIEW_WIDTH, round(PREVIEW_WIDTH * h / w))

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

    # ── palette + color "direction" per wallpaper, for the menu's swatches and filter chips ──
    try:
        palettes = json.loads(WALLPAPERS_PALETTE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        palettes = {}

    palettes = {stem: entry for stem, entry in palettes.items() if stem in valid_stems}

    def needs_palette(src: Path) -> bool:
        entry = palettes.get(src.stem)
        return entry is None or entry.get("mtime", 0) < src.stat().st_mtime

    stale = [src for src in sources if needs_palette(src)]
    if stale:
        def extract(src: Path) -> tuple[str, dict | None]:
            # same source matugen would actually theme from: the small preview when there is one
            colors_src = preview_dir / f"{src.stem}.png"
            palette = extract_palette(colors_src if colors_src.exists() else src)
            return src.stem, palette

        with ThreadPoolExecutor() as pool:
            for future in as_completed(pool.submit(extract, src) for src in stale):
                stem, palette = future.result()
                if palette is not None:
                    src = next(s for s in stale if s.stem == stem)
                    palette["mtime"] = src.stat().st_mtime
                    palettes[stem] = palette
                    print(f"Palette: {stem}")

        WALLPAPERS_PALETTE_FILE.write_text(json.dumps(palettes, indent=2) + "\n")


if __name__ == "__main__":
    main()
