#!/usr/bin/env python3

import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from config import ROFI_THEME_NERDFONT

NERDFONT_TXT = Path(__file__).parent.parent / "helpers" / "nerdfont.txt"

if not shutil.which("rofi"):
    subprocess.run(["notify-send", "Nerd Font", "rofi is not installed"])
    sys.exit(1)

data = NERDFONT_TXT.read_bytes().replace(b" ", b"   ") # make more space between icon and id

result = subprocess.run(
    ["rofi", "-dmenu", "-p", "Nerd Font", "-theme", str(ROFI_THEME_NERDFONT)],
    input=data,
    capture_output=True,
)
if result.returncode != 0:
    sys.exit(1)

icon = result.stdout.decode().split()[0]
subprocess.run(["wl-copy"], input=icon.encode())
