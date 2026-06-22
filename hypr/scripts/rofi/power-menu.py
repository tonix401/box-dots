#!/usr/bin/env python3

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from config import ROFI_THEME_POWER

OPTIONS = [
    ("󰐥  Shutdown",         ["systemctl", "poweroff"]),
    ("󰜉  Reboot",           ["systemctl", "reboot"]),
    ("󰍛  Reboot into UEFI", ["systemctl", "reboot", "--firmware-setup"]),
    ("󰌾  Lock",             ["hyprlock"]),
    ("󰍃  Log out",          ["hyprshutdown", "-vt", "2"]),
    ("󱚡  Kill open Apps",   None),
]

menu_input = "\n".join(label for label, _ in OPTIONS).encode()
result = subprocess.run(
    ["rofi", "-dmenu", "-p", "Power", "-matching", "fuzzy", "-theme", str(ROFI_THEME_POWER)],
    input=menu_input,
    capture_output=True,
)
if result.returncode != 0:
    sys.exit(0)

chosen = result.stdout.decode().strip()
cmd = next((cmd for label, cmd in OPTIONS if label == chosen), None)

if cmd is None and chosen == "󱚡  Kill open Apps":
    clients = subprocess.run(["hyprctl", "-j", "clients"], capture_output=True, text=True)
    pids = [str(c["pid"]) for c in json.loads(clients.stdout) if "pid" in c]
    if pids:
        subprocess.run(["kill"] + pids)
elif cmd is not None:
    subprocess.run(cmd)
