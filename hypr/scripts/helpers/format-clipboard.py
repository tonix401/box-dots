#!/usr/bin/env python3
import re
import sys

HEX_COLOR = re.compile(r"(#[0-9a-fA-F]{6})")
ANSI_ESCAPE = re.compile(r"(?:\x1b|\\e|\\033|\\x1b)\[([0-9;]*)m")

_ANSI_16 = [
    "#000000", "#aa0000", "#00aa00", "#aaaa00",
    "#0000aa", "#aa00aa", "#00aaaa", "#aaaaaa",
    "#555555", "#ff5555", "#55ff55", "#ffff55",
    "#5555ff", "#ff55ff", "#55ffff", "#ffffff",
]

def _color_256(n: int) -> str:
    if n < 16:
        return _ANSI_16[n]
    if n < 232:
        n -= 16
        r, g, b = n // 36, (n // 6) % 6, n % 6
        def c(x): return 0 if x == 0 else 55 + x * 40
        return f"#{c(r):02x}{c(g):02x}{c(b):02x}"
    v = 8 + (n - 232) * 10
    return f"#{v:02x}{v:02x}{v:02x}"

def _ansi_color(params_str: str) -> str | None:
    params = [int(x) if x else 0 for x in params_str.split(";")] if params_str else [0]
    i = 0
    while i < len(params):
        p = params[i]
        if 30 <= p <= 37:
            return _ANSI_16[p - 30]
        if 90 <= p <= 97:
            return _ANSI_16[p - 82]
        if p == 38:
            if i + 2 < len(params) and params[i + 1] == 5:
                return _color_256(params[i + 2])
            if i + 4 < len(params) and params[i + 1] == 2:
                r, g, b = params[i + 2], params[i + 3], params[i + 4]
                return f"#{r:02x}{g:02x}{b:02x}"
        i += 1
    return None

def _replace_ansi(m: re.Match) -> str:
    color = _ansi_color(m.group(1))
    if color:
        return f'<span foreground="{color}">{m.group(0)}</span>'
    return m.group(0)

def format_line(line: str) -> str:
    line = HEX_COLOR.sub(r'<span foreground="\1">\1</span>', line)
    return ANSI_ESCAPE.sub(_replace_ansi, line)

for line in sys.stdin:
    sys.stdout.write(format_line(line))
