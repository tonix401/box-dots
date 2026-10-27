#!/usr/bin/env python3
"""Write unicode.txt next to this script for the Unicode picker (quickshell/menus/SymbolMenu.qml).

One line per named character: "<code point hex>\t<name, lowercase>". Characters named only by their
code point (CJK ideographs, Hangul syllables, Tangut, ...) are left out: there's nothing to search
them by. Rerun after a Python update to pick up a newer Unicode version.
"""

import re
import sys
import unicodedata
from pathlib import Path

numbered = re.compile(r"-[0-9A-F]{4,6}$")

lines = []
for cp in range(sys.maxunicode + 1):
    name = unicodedata.name(chr(cp), "")
    if not name or numbered.search(name) or name.startswith("HANGUL SYLLABLE "):
        continue
    lines.append(f"{cp:04X}\t{name.lower()}\n")

out = Path(__file__).with_name("unicode.txt")
out.write_text("".join(lines))
print(f"{len(lines)} characters (Unicode {unicodedata.unidata_version}) -> {out}")
