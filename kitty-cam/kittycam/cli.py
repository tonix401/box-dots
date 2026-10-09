"""Kitty Cam: the cat as a webcam for video calls (README.md).

    kitty-cam                    serve the page, open it in its own Chromium window and feed every frame it
                                 draws to the "Kitty Cam" camera (PipeWire); closing the window stops it
    kitty-cam --headless         the same without a window (nothing to cover, nothing to throttle);
                                 the controls stay reachable at http://127.0.0.1:8737/
    kitty-cam --no-browser       only serve; open the page yourself
    kitty-cam --stop             stop the running instance
    kitty-cam --no-camera --port 8738 --no-browser
                                 a second instance for testing, leaving the camera to the first

In the call, pick "Kitty Cam" as the camera.
"""
import argparse
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

from . import browser
from .assets import fetch_vendor
from .camera import LABEL, SETUP, Camera, available
from .log import log
from .paths import RUNTIME
from .server import make_server

PORT = 8737  # keep it: the page's settings and calibration live in this origin's localStorage


def pid_file(port):
    return RUNTIME / f"kitty-cam-{port}.pid"


def running_pid(port):
    """The pid of a Kitty Cam serving `port`, or None."""
    try:
        pid = int(pid_file(port).read_text())
        if b"kitty-cam" in Path(f"/proc/{pid}/cmdline").read_bytes():
            return pid
    except (OSError, ValueError):
        pass
    return None


def stop(port):
    pid = running_pid(port)
    if pid is None:
        sys.exit("kitty-cam: not running")
    os.kill(pid, signal.SIGTERM)
    for _ in range(50):
        if running_pid(port) is None:
            return
        time.sleep(0.1)
    sys.exit(f"kitty-cam: {pid} is still running")


def parse_args():
    ap = argparse.ArgumentParser(prog="kitty-cam", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--headless", action="store_true", help="run Chromium without a window")
    mode.add_argument("--no-browser", action="store_true", help="only serve the page")
    mode.add_argument("--stop", action="store_true", help="stop the running instance")
    ap.add_argument("--port", type=int, default=PORT, help=f"port to serve on (default {PORT})")
    ap.add_argument("--no-camera", action="store_true", help=f"don't write to the {LABEL} camera")
    ap.add_argument("--theme", type=Path, default=os.environ.get("KITTY_CAM_THEME") or None,
                    help="colours as a Material-You palette JSON (matugen's shape); default $KITTY_CAM_THEME")
    return ap.parse_args()


def main():
    args = parse_args()
    if args.stop:
        return stop(args.port)

    fetch_vendor()
    enabled = not args.no_camera and available()
    if args.no_camera:
        log("not writing to the camera (--no-camera)")
    elif enabled:
        log(f"camera: \"{LABEL}\" in PipeWire")
    else:
        log(SETUP)
    camera = Camera(enabled)

    try:
        server = make_server(args.port, camera, args.theme)
    except OSError as e:
        sys.exit(f"kitty-cam: can't listen on port {args.port} ({e.strerror}); is it running already?")
    pid_file(args.port).parent.mkdir(parents=True, exist_ok=True)
    pid_file(args.port).write_text(str(os.getpid()))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{args.port}/"
    log(f"serving {url}")

    window = None
    if not args.no_browser:
        window = browser.launch(url, args.headless)
        if window is None:
            log(f"no Chromium found; open {url} in a Chromium-based browser")

    done = threading.Event()
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):  # SIGHUP: its terminal was closed
        signal.signal(sig, lambda *_: done.set())
    started = time.monotonic()
    while not done.wait(0.5):
        if window and window.poll() is not None:
            if time.monotonic() - started < 3:  # handed over to a Chromium already on that profile
                log("Chromium handed the window to an instance that was already running; kitty-cam --stop to stop")
                window = None
            else:
                break  # the window was closed
    if window and window.poll() is None:
        window.terminate()
        try:
            window.wait(5)
        except subprocess.TimeoutExpired:
            window.kill()
    server.shutdown()
    camera.close()
    pid_file(args.port).unlink(missing_ok=True)
