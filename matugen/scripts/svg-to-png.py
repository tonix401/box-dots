#!/usr/bin/env python3
"""Convert an SVG file to PNG using rsvg-convert (fastest available method)."""
import sys
import subprocess
from pathlib import Path

svg_path, png_path = Path(sys.argv[1]), Path(sys.argv[2])
png_path.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(["rsvg-convert", "-o", str(png_path), str(svg_path)], check=True)
