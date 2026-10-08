#!/usr/bin/env python3
"""Kitty Cam: the cat as a webcam for video calls (SPEC.md, "Kitty Cam").

    kitty-cam.py                 serve kitty-cam.html, open it in its own Chromium window and feed
                                 every frame it draws to the "Kitty Cam" camera (v4l2loopback)
    kitty-cam.py --headless      the same without a window (nothing to cover, nothing to throttle);
                                 the controls stay reachable at http://127.0.0.1:8737/
    kitty-cam.py --no-browser    only serve; open the page yourself
    kitty-cam.py --no-camera --port 8738 --no-browser
                                 a second instance for testing, leaving the camera to the first

The page tracks your face (MediaPipe Face Landmarker) and your voice, drives the cat with engine.js
and POSTs each frame, already converted to YUV 4:2:0, to /frame; it's written to the camera as it is. In the call,
pick "Kitty Cam" as the camera. MediaPipe and its model are downloaded once to ~/.cache/kitty-cam.
"""
import argparse
import fcntl
import json
import os
import shutil
import struct
import signal
import subprocess
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
PAGE = HERE / "kitty-cam.html"
CACHE = Path.home() / ".cache/kitty-cam"
THEME = Path.home() / ".config/quickshell/colors.json"  # matugen's palette, as the kitty cats use it
PALETTE = ["primary", "secondary", "tertiary", "inverse_primary", "primary_container", "secondary_container",
           "tertiary_container", "on_primary_container", "on_secondary_container", "on_tertiary_container",
           "surface_container_highest", "on_surface", "outline", "error"]  # the page's colour swatches
PORT = 8737
LABEL = "Kitty Cam"
TASKS_VISION = "1.0.1"  # @mediapipe/tasks-vision; kitty-cam.html imports /vendor/vision_bundle.mjs
VENDOR = {
    "vision_bundle.mjs": f"https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@{TASKS_VISION}/vision_bundle.mjs",
    "wasm/vision_wasm_internal.js": f"https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@{TASKS_VISION}/wasm/vision_wasm_internal.js",
    "wasm/vision_wasm_internal.wasm": f"https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@{TASKS_VISION}/wasm/vision_wasm_internal.wasm",
    "face_landmarker.task": "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task",
}
VENDOR_DIR = CACHE / "vendor" / TASKS_VISION
TYPES = {".html": "text/html; charset=utf-8", ".mjs": "text/javascript", ".js": "text/javascript",
         ".wasm": "application/wasm", ".task": "application/octet-stream", ".json": "application/json"}
SETUP = f"""No "{LABEL}" camera. Set up v4l2loopback once:
    sudo pacman -S --needed v4l2loopback-dkms
    echo 'options v4l2loopback video_nr=10 card_label="{LABEL}" exclusive_caps=1' | sudo tee /etc/modprobe.d/v4l2loopback.conf
    echo v4l2loopback | sudo tee /etc/modules-load.d/v4l2loopback.conf
    sudo modprobe v4l2loopback
Running anyway: the page works, but no call can see the cat."""


def log(msg):
    print(f"kitty-cam: {msg}", file=sys.stderr, flush=True)


def fetch_vendor():
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


def find_device():
    for d in sorted(Path("/sys/class/video4linux").glob("video*")):
        try:
            if (d / "name").read_text().strip() == LABEL:
                return f"/dev/{d.name}"
        except OSError:
            pass
    return None


# V4L2, from <linux/videodev2.h> (checked against the headers with a C compile, 2026-10-08)
VIDIOC_G_FMT, VIDIOC_S_FMT = 0xC0D05604, 0xC0D05605  # struct v4l2_format: 208 bytes, pix at offset 8
V4L2_BUF_TYPE_VIDEO_OUTPUT, V4L2_FIELD_NONE = 2, 1
V4L2_PIX_FMT_YUV420 = 0x32315559  # "YU12": planar Y, then U and V at quarter size
WIDTH, HEIGHT = 1280, 720
FRAME_BYTES = WIDTH * HEIGHT * 3 // 2


class Camera:
    """The loopback camera. The page sends finished YUV 4:2:0 frames and they're written to the device
    as they are: no encoding, no ffmpeg. (ffmpeg's image2pipe held each frame ~100 ms.)"""

    def __init__(self, device):
        self.device = device
        self.fd = None
        self.lock = threading.Lock()
        self.frames = 0
        self.last = 0.0
        self.stats = {}  # the page's own figures (tracking fps, face found, …), sent along with frames
        self.arrival_ms = 0.0  # how long frames take from being drawn to reaching us (eased average)

    def open(self):
        fd = os.open(self.device, os.O_RDWR)
        fmt = bytearray(208)
        struct.pack_into("I", fmt, 0, V4L2_BUF_TYPE_VIDEO_OUTPUT)
        struct.pack_into("8I", fmt, 8, WIDTH, HEIGHT, V4L2_PIX_FMT_YUV420, V4L2_FIELD_NONE, WIDTH, FRAME_BYTES, 0, 0)
        try:
            fcntl.ioctl(fd, VIDIOC_S_FMT, fmt)
        except OSError as e:
            # Busy: a reader (OBS, a call) is streaming. Fine if the format it has is already ours.
            cur = bytearray(208)
            struct.pack_into("I", cur, 0, V4L2_BUF_TYPE_VIDEO_OUTPUT)
            fcntl.ioctl(fd, VIDIOC_G_FMT, cur)
            if struct.unpack_from("3I", cur, 8) != (WIDTH, HEIGHT, V4L2_PIX_FMT_YUV420):
                os.close(fd)
                raise OSError(e.errno, f"{self.device} is busy with another format ({e.strerror})")
        return fd

    def write(self, frame):
        if not self.device or len(frame) != FRAME_BYTES:
            return False
        with self.lock:
            try:
                if self.fd is None:
                    self.fd = self.open()
                os.write(self.fd, frame)
            except OSError as e:
                log(f"writing to {self.device}: {e.strerror or e}")
                if self.fd is not None:
                    os.close(self.fd)
                self.fd = None
                return False
            self.frames += 1
            self.last = time.monotonic()
            return True

    def close(self):
        with self.lock:
            if self.fd is not None:
                os.close(self.fd)
                self.fd = None


def handler(camera):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, status, body=b"", ctype="text/plain"):
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = self.path.split("?")[0]
            if path == "/":
                return self.send(200, PAGE.read_bytes(), TYPES[".html"])
            if path == "/status":
                return self.send(200, json.dumps({"device": camera.device, "frames": camera.frames, "page": camera.stats,
                                                  "drawn_to_helper_ms": round(camera.arrival_ms, 1)}).encode(), TYPES[".json"])
            if path == "/theme":
                try:
                    c = json.loads(THEME.read_text())
                    theme = {"cat": c["primary"], "background": c["surface"], "fill": c["primary_container"],
                             "palette": {role: c[role] for role in PALETTE if role in c}}
                except (OSError, ValueError, KeyError):
                    theme = {}
                return self.send(200, json.dumps(theme).encode(), TYPES[".json"])
            if path.startswith("/vendor/"):
                name = path[len("/vendor/"):]
                if name in VENDOR:
                    f = VENDOR_DIR / name
                    return self.send(200, f.read_bytes(), TYPES.get(f.suffix, "application/octet-stream"))
            self.send(404, b"not found")

        def do_POST(self):
            if self.path != "/frame":
                return self.send(404, b"not found")
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            try:
                camera.stats = json.loads(self.headers.get("X-Kitty-Stats", "{}"))
                drawn = float(self.headers.get("X-Kitty-Drawn", "nan"))
                if drawn == drawn:  # not NaN
                    camera.arrival_ms += (time.time() * 1000 - drawn - camera.arrival_ms) * 0.1
            except ValueError:
                pass
            # 204: the frame reached the camera; 503: it didn't (no camera, wrong size, device error).
            self.send(204 if camera.write(body) else 503)

    return Handler


def features(*extra):
    """Chromium keeps only the last --enable-features, and /usr/bin/chromium puts ~/.config/chromium-flags.conf
    first, so ours has to carry that file's features too."""
    have = []
    try:
        for word in (Path.home() / ".config/chromium-flags.conf").read_text().split():
            if word.startswith("--enable-features="):
                have += word.split("=", 1)[1].split(",")
    except OSError:
        pass
    return have + [f for f in extra if f not in have]


def chromium(url, headless):
    profile = CACHE / "chromium"  # its own profile: the flags apply, and the camera permission sticks
    args = ["chromium", f"--user-data-dir={profile}", "--no-first-run", "--no-default-browser-check",
            # Keep tracking and drawing while the call's window covers this one.
            "--disable-background-timer-throttling", "--disable-renderer-backgrounding",
            "--disable-backgrounding-occluded-windows", "--disable-background-media-suspend",
            "--autoplay-policy=no-user-gesture-required",  # the mic's AudioContext starts without a click
            # The webcam through PipeWire, which shares it: Discord and OBS can use it while this tracks.
            f"--enable-features={','.join(features('WebRtcPipeWireCamera'))}"]
    # With a window, the camera/mic prompt comes once and the profile remembers the answer
    # (--use-fake-ui-for-media-stream would show an "unsupported command-line flag" bar every launch).
    # Headless has nobody to answer it, so there the flag grants them.
    args += ["--headless=new", "--use-fake-ui-for-media-stream", url] if headless else [f"--app={url}"]
    return subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--headless", action="store_true", help="run Chromium without a window")
    mode.add_argument("--no-browser", action="store_true", help="only serve the page")
    ap.add_argument("--port", type=int, default=PORT, help=f"port to serve on (default {PORT})")
    ap.add_argument("--no-camera", action="store_true", help="don't write to the Kitty Cam camera")
    args = ap.parse_args()

    fetch_vendor()
    device = None if args.no_camera else find_device()
    if args.no_camera:
        log("not writing to the camera (--no-camera)")
    elif device:
        log(f"camera {device} (\"{LABEL}\")")
    else:
        log(SETUP)
    camera = Camera(device)
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), handler(camera))
    except OSError as e:
        sys.exit(f"kitty-cam: can't listen on port {args.port} ({e.strerror}); is it running already?")
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{args.port}/"
    log(f"serving {url}")

    browser = None if args.no_browser else chromium(url, args.headless)
    stop = threading.Event()
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):  # SIGHUP: its terminal was closed
        signal.signal(sig, lambda *_: stop.set())
    started = time.monotonic()
    while not stop.wait(0.5):
        if browser and browser.poll() is not None:
            if time.monotonic() - started < 3:  # handed over to a Chromium already on that profile
                log("Chromium handed the window to an instance that was already running; Ctrl-C to stop")
                browser = None
            else:
                break  # the window was closed
    if browser and browser.poll() is None:
        browser.terminate()
        try:
            browser.wait(5)
        except subprocess.TimeoutExpired:
            browser.kill()
    server.shutdown()
    camera.close()


if __name__ == "__main__":
    main()
