"""Where Kitty Cam finds its own files and keeps its state. Everything it ships is relative to the app's
folder, so the folder can live anywhere; what it creates follows the XDG base directories."""
import os
from pathlib import Path


def _xdg(var, fallback):
    value = os.environ.get(var)
    return Path(value) if value and os.path.isabs(value) else Path.home() / fallback


APP = Path(__file__).resolve().parent.parent  # the kitty-cam folder
WEB = APP / "web"  # the page, served as it is
CACHE = _xdg("XDG_CACHE_HOME", ".cache") / "kitty-cam"  # MediaPipe downloads, the Chromium profile
CONFIG = _xdg("XDG_CONFIG_HOME", ".config")
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or CACHE)  # the pid file of a running instance
