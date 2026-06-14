#!/usr/bin/env python3

import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from config import ROFI_THEME_EMOJI

if not shutil.which("rofimoji"):
    subprocess.run(["notify-send", "Emoji", "rofimoji is not installed"])
    sys.exit(1)

subprocess.run([
    "rofimoji",
    "--action", "clipboard",
    "--skin-tone", "neutral",
    "--prompt", "Emoji ",
    "--selector-args", f"-theme {ROFI_THEME_EMOJI}",
])
