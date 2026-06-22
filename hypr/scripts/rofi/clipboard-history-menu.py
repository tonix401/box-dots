#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from config import ROFI_THEME_CLIPBOARD

HELPERS_DIR = Path(__file__).parent.parent / "helpers"

if not shutil.which("cliphist"):
    subprocess.run(["notify-send", "Clipboard", "cliphist is not installed"])
    sys.exit(1)

thumb_dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "cliphist-thumbs"
thumb_dir.mkdir(parents=True, exist_ok=True)

entries_result = subprocess.run(["cliphist", "list"], capture_output=True)
if entries_result.returncode != 0:
    sys.exit(1)
entries_text = entries_result.stdout.decode("utf-8", errors="replace")

subprocess.run(
    [sys.executable, str(HELPERS_DIR / "generate-thumbs.py"), str(thumb_dir)],
    input=entries_text.encode(),
)

rofi_input = bytearray()
for line in entries_text.splitlines():
    id_, _, rest = line.partition("\t")
    if "[[ binary data" in rest:
        thumb = thumb_dir / f"{id_}.png"
        if thumb.exists():
            rofi_input += f"{id_}\t{rest}\x00icon\x1f{thumb}\n".encode()
            continue
    rofi_input += f"{id_}\t{rest}\n".encode()

format_proc = subprocess.run(
    [sys.executable, str(HELPERS_DIR / "format-clipboard.py")],
    input=bytes(rofi_input),
    capture_output=True,
)

rofi_proc = subprocess.run(
    ["rofi", "-dmenu", "-p", "Clipboard", "-theme", str(ROFI_THEME_CLIPBOARD), "-markup-rows"],
    input=format_proc.stdout,
    capture_output=True,
)
if rofi_proc.returncode != 0:
    sys.exit(0)

decode_proc = subprocess.run(["cliphist", "decode"], input=rofi_proc.stdout, capture_output=True)
subprocess.run(["wl-copy"], input=decode_proc.stdout)
