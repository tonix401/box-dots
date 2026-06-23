#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ROFI_THEME_LAUNCHER


subprocess.run(["rofi", "-show", "drun", "-matching", "fuzzy", "-theme", str(ROFI_THEME_LAUNCHER)])