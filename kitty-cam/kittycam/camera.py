"""The "Kitty Cam" camera: a PipeWire camera, so any number of apps can use it at once (Chromium with
WebRtcPipeWireCamera, OBS's PipeWire source).

The page sends frames already in YUV 4:2:0 (I420), and gst-launch publishes them as a PipeWire video source
(pipewiresink mode=provide), started on the first frame. They go out as YUY2: Chromium's PipeWire camera
shows no frames for I420 or NV12 (Chromium 153, tested 2026-10-09).
"""
import os
import shutil
import signal
import subprocess
import threading
import time
from pathlib import Path

from .log import log

LABEL = "Kitty Cam"  # the camera's name in apps
NODE = "kitty_cam"  # its PipeWire node.name, by which OBS's PipeWire source remembers it
WIDTH, HEIGHT = 1280, 720
FRAME_BYTES = WIDTH * HEIGHT * 3 // 2
RETRY = 2.0  # seconds before starting the pipeline again after it failed

SETUP = f"""No "{LABEL}" camera: it needs GStreamer with PipeWire's plugin (Arch:
    sudo pacman -S --needed gstreamer gst-plugins-base gst-plugin-pipewire
and PipeWire running). Running anyway: the page works, but no call can see the cat."""

PIPELINE = [
    "gst-launch-1.0", "-q",
    "fdsrc", "fd=0", f"blocksize={FRAME_BYTES}",
    "!", "rawvideoparse", f"width={WIDTH}", f"height={HEIGHT}", "format=i420", "framerate=30/1",
    "colorimetry=bt601",
    # Never hold up the writes: if PipeWire stalls, frames are dropped here instead.
    "!", "queue", "leaky=downstream", "max-size-buffers=2", "max-size-bytes=0", "max-size-time=0",
    "!", "videoconvert", "!", "video/x-raw,format=YUY2",
    "!", "pipewiresink", "mode=provide", "sync=false", "client-name=kitty-cam",
    # gst-launch joins its arguments with spaces and parses the result: values with spaces need its quotes
    f'stream-properties="props,media.class=Video/Source,media.role=Camera,node.name={NODE},'
    f'node.description=\\"{LABEL}\\""',
]


def available():
    """Whether gst-launch and the elements the pipeline uses are installed."""
    if not (shutil.which("gst-launch-1.0") and shutil.which("gst-inspect-1.0")):
        return False
    elements = ("fdsrc", "rawvideoparse", "queue", "videoconvert", "pipewiresink")
    return all(subprocess.run(["gst-inspect-1.0", "--exists", e]).returncode == 0 for e in elements)


class Camera:
    """The PipeWire camera, started on the first frame and restarted after an error. `node` None: frames
    are dropped (no GStreamer, or --no-camera)."""

    def __init__(self, enabled):
        self.node = NODE if enabled else None
        self.proc = None
        self.retry_at = 0.0
        self.lock = threading.Lock()
        self.frames = 0
        self.last = 0.0
        self.stats = {}  # the page's own figures (tracking fps, face found, …), sent along with frames
        self.arrival_ms = 0.0  # how long frames take from being drawn to reaching us (eased average)

    def _stop(self):
        # Stopped, not ended: gst-launch doesn't exit when its input closes (pipewiresink never finishes the
        # end of stream), so a pipeline whose kitty-cam was killed outright lives on; see _kill_stale.
        proc, self.proc = self.proc, None
        if proc is None:
            return
        try:
            proc.stdin.close()
        except OSError:
            pass
        proc.terminate()
        try:
            proc.wait(3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()

    @staticmethod
    def _kill_stale():
        """Stop pipelines left by a kitty-cam that was killed: a second "Kitty Cam" that never sends a frame."""
        mark = f"node.name={NODE},".encode()
        for proc in Path("/proc").iterdir():
            if not proc.name.isdigit():
                continue
            try:
                cmd = (proc / "cmdline").read_bytes()
                if cmd.startswith(b"gst-launch-1.0\0") and mark in cmd:
                    log(f"stopping a leftover camera pipeline ({proc.name})")
                    os.kill(int(proc.name), signal.SIGTERM)
            except (OSError, ValueError):
                continue

    def write(self, frame):
        """Write one frame; False if it didn't reach the camera (none, wrong size, pipeline down)."""
        if not self.node or len(frame) != FRAME_BYTES:
            return False
        with self.lock:
            if self.proc and self.proc.poll() is not None:
                log(f"the camera's gst-launch exited ({self.proc.returncode}); restarting in {RETRY:.0f} s")
                self._stop()
                self.retry_at = time.monotonic() + RETRY
            if self.proc is None:
                if time.monotonic() < self.retry_at:
                    return False
                self._kill_stale()
                self.proc = subprocess.Popen(PIPELINE, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, bufsize=0)
            try:
                view = memoryview(frame)
                while view:
                    view = view[self.proc.stdin.write(view):]
            except OSError as e:
                log(f"writing to the camera's gst-launch: {e.strerror or e}")
                self._stop()
                self.retry_at = time.monotonic() + RETRY
                return False
            self.frames += 1
            self.last = time.monotonic()
            return True

    def close(self):
        with self.lock:
            self._stop()
