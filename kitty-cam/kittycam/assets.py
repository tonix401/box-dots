"""MediaPipe's Face Landmarker (library, wasm and model), downloaded once into the cache and served from
there under /vendor/. Pinned, so the page always gets the version it was written against."""
import shutil
import urllib.request

from .log import log
from .paths import CACHE

TASKS_VISION = "1.0.1"  # @mediapipe/tasks-vision; web/js/tracker.js imports /vendor/vision_bundle.mjs
_NPM = f"https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@{TASKS_VISION}"
VENDOR = {
    "vision_bundle.mjs": f"{_NPM}/vision_bundle.mjs",
    "wasm/vision_wasm_internal.js": f"{_NPM}/wasm/vision_wasm_internal.js",
    "wasm/vision_wasm_internal.wasm": f"{_NPM}/wasm/vision_wasm_internal.wasm",
    "face_landmarker.task": "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task",
}
VENDOR_DIR = CACHE / "vendor" / TASKS_VISION


def fetch_vendor():
    """Download whatever isn't in the cache yet (atomically: a broken download never counts as done)."""
    for name, url in VENDOR.items():
        dest = VENDOR_DIR / name
        if dest.exists():
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        log(f"downloading {name}")
        tmp = dest.with_suffix(dest.suffix + ".part")
        with urllib.request.urlopen(url, timeout=60) as r, open(tmp, "wb") as f:
            shutil.copyfileobj(r, f)
        tmp.rename(dest)
