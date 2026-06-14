#!/usr/bin/env python3

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from config import SCREENSHOTS_DIR

SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)

result = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True)
try:
    win_class = json.loads(result.stdout).get("class", "unknown") or "unknown"
except Exception:
    win_class = "unknown"

win_safe = win_class.replace(" ", "_").replace("/", "_").replace("\\", "_")
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
file = SCREENSHOTS_DIR / f"{timestamp}_{win_safe}.png"

subprocess.run(["grimblast", "copysave", "area", str(file)], check=True)
