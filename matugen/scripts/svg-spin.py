#!/usr/bin/env python3
"""Render an SVG as a GIF spinning horizontally (about its vertical axis, like a coin).

Each frame squeezes the drawing's width by cos(angle) around its center, so the back half of the
turn comes out mirrored. Frames are drawn by rsvg-convert, so they stay sharp, and joined by
ImageMagick. GIF because kitty's icat plays it (it doesn't animate WebP or APNG).

usage: svg-spin.py IN.svg OUT.gif [SIZE_PX] [FRAMES] [SECONDS_PER_TURN]
"""
import math
import re
import subprocess
import sys
import tempfile
from pathlib import Path

svg_path, gif_path = Path(sys.argv[1]), Path(sys.argv[2])
size = int(sys.argv[3]) if len(sys.argv) > 3 else 300
frames = int(sys.argv[4]) if len(sys.argv) > 4 else 36
turn = float(sys.argv[5]) if len(sys.argv) > 5 else 3.0

src = svg_path.read_text()
outer = re.search(r"<svg\b[^>]*>", src)
x, y, w, h = map(float, re.search(r'viewBox="([^"]+)"', outer.group(0)).group(1).replace(",", " ").split())
inner = src[outer.end():src.rindex("</svg>")]
cx = x + w / 2

with tempfile.TemporaryDirectory() as tmp:
    pngs = []
    for i in range(frames):
        c = math.cos(2 * math.pi * i / frames)
        frame = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size * h / w:.0f}" '
                 f'viewBox="{x} {y} {w} {h}"><g transform="translate({cx} 0) scale({c:.5f} 1) '
                 f'translate({-cx} 0)">{inner}</g></svg>')
        svg = Path(tmp, f"{i:03d}.svg")
        svg.write_text(frame)
        png = svg.with_suffix(".png")
        subprocess.run(["rsvg-convert", "-o", str(png), str(svg)], check=True)
        pngs.append(str(png))

    gif_path.parent.mkdir(parents=True, exist_ok=True)
    out = gif_path.with_name(gif_path.name + ".tmp.gif")  # swapped in whole, so fastfetch never reads half a file
    delay = max(2, round(turn * 100 / frames))  # GIF delays are in 1/100 s
    subprocess.run(["magick", "-delay", str(delay), "-loop", "0", "-dispose", "background", *pngs, str(out)], check=True)
    out.replace(gif_path)
