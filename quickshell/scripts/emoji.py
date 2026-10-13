#!/usr/bin/env python3
"""rofimoji's data for the Quickshell emoji menu, using rofimoji's own loader so the
list (frecent first, same files, same order) and its history stay identical.

  emoji.py list         -> JSON array of [character, description-with-<small>-markup], also written to CACHE
  emoji.py pick <char>  -> records the pick in rofimoji's frecency/recent files and rewrites CACHE

The menu shows CACHE right away (starting Python + rofimoji takes ~80ms) and runs `list` in the background
to refresh it; `pick` rewrites it so the frecent order is current on the next open.
"""
import json
import os
import sys
from pathlib import Path

from picker.argument_parsing import parse_arguments_flexible
from picker.file_loader import read_characters_from_files
from picker.frecent import load_frecent_characters, save_frecent_characters
from picker.recent import save_recent_characters

CACHE = Path.home() / ".cache/box-dots/emoji-list.json"

cmd, rest = (sys.argv[1] if len(sys.argv) > 1 else "list"), sys.argv[2:]
sys.argv = sys.argv[:1]  # rofimoji's parser reads sys.argv; give it the defaults
args = parse_arguments_flexible()


def listing() -> str:
    entries = read_characters_from_files(
        args.files, load_frecent_characters() if args.frecency else [], args.use_additional
    )
    text = json.dumps([[e.character, e.description] for e in entries], ensure_ascii=False)
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE.with_suffix(".tmp")
    tmp.write_text(text)
    os.replace(tmp, CACHE)  # atomic, so the menu never reads half a file
    return text


if cmd == "list":
    sys.stdout.write(listing())
elif cmd == "pick" and rest:
    save_frecent_characters(rest[0])
    save_recent_characters(rest[0], args.max_recent, args.files)
    listing()
