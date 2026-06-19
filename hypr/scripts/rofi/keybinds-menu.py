#!/usr/bin/env python3

import json
import re
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

def collapse_numbered(entries):
    groups = {}
    singles = []
    order = []

    for desc, combo in entries:
        dm = re.fullmatch(r'(.+)\s+(\d)', desc)
        cm = re.fullmatch(r'(.+ \+) (\d)', combo)
        if dm and cm and dm.group(2) == cm.group(2):
            key = (dm.group(1), cm.group(1))
            if key not in groups:
                groups[key] = []
                order.append(('group', key))
            groups[key].append(int(dm.group(2)))
        else:
            order.append(('single', len(singles)))
            singles.append((desc, combo))

    result = []
    for kind, key in order:
        if kind == 'single':
            result.append(singles[key])
        else:
            digits = sorted(groups[key])
            desc_prefix, combo_prefix = key
            if len(digits) > 1 and digits == list(range(digits[0], digits[-1] + 1)):
                r = f"[{digits[0]}-{digits[-1]}]"
                result.append((f"{desc_prefix} {r}", f"{combo_prefix} {r}"))
            else:
                for d in digits:
                    result.append((f"{desc_prefix} {d}", f"{combo_prefix} {d}"))
    return result

entries = collapse_numbered([(b["description"], build_combo(b)) for b in binds])

pad = max(len(desc) for desc, _ in entries) + 4
lines = [f"{desc.ljust(pad)}{combo}" for desc, combo in entries]

result = subprocess.run(
    ["rofi", "-dmenu", "-p", "Keybinds", "-theme", str(ROFI_THEME_KEYBINDS), "-i"],
    input="\n".join(lines).encode(),
    capture_output=True,
)
