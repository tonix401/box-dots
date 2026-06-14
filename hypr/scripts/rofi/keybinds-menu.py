#!/usr/bin/env python3

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from config import ROFI_THEME_KEYBINDS

MODIFIERS = [
    (64, "SUPER"),
    (4,  "CTRL"),
    (1,  "SHIFT"),
    (8,  "ALT"),
]

KEY_NAMES = {
    "return":    "Return",
    "space":     "Space",
    "escape":    "Escape",
    "period":    ".",
    "backspace": "Backspace",
    "tab":       "Tab",
    "left":      "Left",
    "right":     "Right",
    "up":        "Up",
    "down":      "Down",
}

def build_combo(bind):
    mods = [name for bit, name in MODIFIERS if bind["modmask"] & bit]
    key  = KEY_NAMES.get(bind["key"].lower(), bind["key"])
    return " + ".join(mods + [key]) # type: ignore

binds_result = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True)
if binds_result.returncode != 0:
    sys.exit(1)

binds = [
    b for b in json.loads(binds_result.stdout)
    if b.get("has_description")
    and not b.get("mouse")
    and "mouse:" not in b.get("key", "")
]

if not binds:
    subprocess.run(["notify-send", "Keybinds", "No keybinds with descriptions found"])
    sys.exit(0)

entries = [(b["description"], build_combo(b)) for b in binds]

pad = max(len(desc) for desc, _ in entries) + 4
lines = [f"{desc.ljust(pad)}{combo}" for desc, combo in entries]

result = subprocess.run(
    ["rofi", "-dmenu", "-p", "Keybinds", "-theme", str(ROFI_THEME_KEYBINDS), "-i"],
    input="\n".join(lines).encode(),
    capture_output=True,
)
