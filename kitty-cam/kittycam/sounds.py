"""The soundboard's files: the audio in sounds/ (this folder's), and sounds/sounds.json with each pad's order,
name, volume and effects (the page edits them). A file dropped into the folder by hand shows up as a pad with
no effects; an entry whose file is gone is left out.

Also the hub that hands the CLI's `--play` to the page, over Server-Sent Events.
"""
import json
import os
import queue
import re
import threading

from .paths import APP

DIR = APP / "sounds"
CONFIG = DIR / "sounds.json"
AUDIO = {".mp3", ".ogg", ".oga", ".opus", ".wav", ".flac", ".m4a", ".aac", ".webm"}
MAX_BYTES = 20 * 1024 * 1024
lock = threading.Lock()


def audio_file(name):
    """The audio file called `name` in sounds/, or None (missing, not audio, or outside the folder)."""
    f = (DIR / name).resolve()
    return f if f.parent == DIR.resolve() and f.suffix.lower() in AUDIO and f.is_file() else None


def _saved():
    try:
        pads = json.loads(CONFIG.read_text()).get("pads", [])
        return [p for p in pads if isinstance(p, dict) and isinstance(p.get("file"), str)]
    except (OSError, ValueError, AttributeError):
        return []


def pads():
    """The pads in their order: the saved ones whose file is there, then new files by name."""
    with lock:
        files = sorted(f.name for f in DIR.iterdir() if f.is_file() and f.suffix.lower() in AUDIO) if DIR.is_dir() else []
        saved = [p for p in _saved() if p["file"] in files]
        known = {p["file"] for p in saved}
        return saved + [{"file": f} for f in files if f not in known]


def save(new):
    """Keep the page's pads (order, names, volumes, effects)."""
    if not isinstance(new, list) or not all(isinstance(p, dict) and isinstance(p.get("file"), str) for p in new):
        raise ValueError("pads must be a list of {file, …}")
    with lock:
        DIR.mkdir(parents=True, exist_ok=True)
        tmp = CONFIG.with_suffix(".tmp")
        tmp.write_text(json.dumps({"pads": new}, indent=1, ensure_ascii=False) + "\n")
        os.replace(tmp, CONFIG)


def add(name, data):
    """Store a dropped file; returns the name it got (a number is added if the name is taken)."""
    name = os.path.basename(name).strip()
    stem, dot, ext = name.rpartition(".")
    if not dot or "." + ext.lower() not in AUDIO or not stem:
        raise ValueError(f"not an audio file ({', '.join(sorted(AUDIO))})")
    stem = re.sub(r"[\x00-\x1f/\\]", "", stem)[:80] or "sound"
    with lock:
        DIR.mkdir(parents=True, exist_ok=True)
        n, final = 1, f"{stem}.{ext}"
        while (DIR / final).exists():
            n += 1
            final = f"{stem} ({n}).{ext}"
        (DIR / final).write_bytes(data)
    return final


def remove(name):
    f = audio_file(name)
    if f is None:
        return False
    with lock:
        f.unlink()
    save([p for p in _saved() if p["file"] != name])
    return True


def find(which):
    """A pad by its 1-based slot or its file's name (with or without the extension); None if there's none."""
    all_pads = pads()
    if which.isdigit():
        i = int(which) - 1
        return all_pads[i] if 0 <= i < len(all_pads) else None
    for p in all_pads:
        if which in (p["file"], p["file"].rpartition(".")[0], p.get("name")):
            return p
    return None


class Events:
    """Messages for the page (`play <file>`, `stop`), one queue per connected page."""

    def __init__(self):
        self.listeners = set()
        self.lock = threading.Lock()

    def listen(self):
        q = queue.Queue(maxsize=32)
        with self.lock:
            self.listeners.add(q)
        return q

    def leave(self, q):
        with self.lock:
            self.listeners.discard(q)

    def send(self, message):
        """Hand `message` to every page; how many got it."""
        with self.lock:
            for q in self.listeners:
                try:
                    q.put_nowait(message)
                except queue.Full:
                    pass
            return len(self.listeners)
