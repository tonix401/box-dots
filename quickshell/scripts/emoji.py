#!/usr/bin/env python3
"""rofimoji's data for the Quickshell emoji menu, using rofimoji's own loader so the
list (frecent first, same files, same order) and its history stay identical.

  emoji.py list         -> JSON array of [character, description-with-<small>-markup]
  emoji.py pick <char>  -> records the pick in rofimoji's frecency/recent files
"""
import json
import sys

from picker.argument_parsing import parse_arguments_flexible
from picker.file_loader import read_characters_from_files
from picker.frecent import load_frecent_characters, save_frecent_characters
from picker.recent import save_recent_characters

cmd, rest = (sys.argv[1] if len(sys.argv) > 1 else "list"), sys.argv[2:]
sys.argv = sys.argv[:1]  # rofimoji's parser reads sys.argv; give it the defaults
args = parse_arguments_flexible()

if cmd == "list":
    entries = read_characters_from_files(
        args.files, load_frecent_characters() if args.frecency else [], args.use_additional
    )
    json.dump([[e.character, e.description] for e in entries], sys.stdout, ensure_ascii=False)
elif cmd == "pick" and rest:
    save_frecent_characters(rest[0])
    save_recent_characters(rest[0], args.max_recent, args.files)
