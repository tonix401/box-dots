"""The "Kitty Cam Mic": a PipeWire mic that carries your real mic plus the soundboard, so the call hears both.

Two pw-loopback processes, which live exactly as long as kitty-cam (nothing is left loaded after a crash):

    sounds  a sink "Kitty Cam Sounds" (node kitty_cam_sounds) whose input comes out of the source
            "Kitty Cam Mic" (node kitty_cam_mic): the page plays the soundboard into the sink
    voice   the real mic, played into that sink too, so PipeWire adds it to the sounds (no extra delay)

The real mic is the one picked in the page's Input card (it sends its label, matched against PipeWire's
source descriptions), else the default source; never Kitty Cam Mic itself, which would feed back.
"""
import json
import os
import shutil
import signal
import subprocess
import threading
from pathlib import Path

from .log import log

MIC_LABEL = "Kitty Cam Mic"  # the mic's name in apps
MIC_NODE = "kitty_cam_mic"
SINK_LABEL = "Kitty Cam Sounds"  # the page plays the soundboard here (an output device in its list)
SINK_NODE = "kitty_cam_sounds"
VOICE_NODE = "kitty_cam_voice"  # the real mic's loopback

SETUP = f"""No "{MIC_LABEL}": it needs pw-loopback (Arch: pipewire) and PipeWire running. Running anyway:
the soundboard plays only on your speakers, and the call doesn't hear it."""


def available():
    return bool(shutil.which("pw-loopback") and shutil.which("pactl"))


def sources():
    """PipeWire's audio sources as {name, description}, without monitors and without our own mic."""
    try:
        out = subprocess.run(["pactl", "-f", "json", "list", "sources"], capture_output=True, text=True, timeout=3).stdout
        return [{"name": s["name"], "description": s.get("description", "")} for s in json.loads(out)
                if s.get("properties", {}).get("device.class") != "monitor" and not s["name"].endswith(".monitor")
                and not s["name"].startswith("kitty_cam")]
    except (OSError, subprocess.SubprocessError, ValueError, KeyError):
        return []


def default_source():
    try:
        return subprocess.run(["pactl", "get-default-source"], capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


class Mic:
    """The virtual mic, made by start(). `node` None: not made (no pw-loopback, or --no-camera)."""

    def __init__(self, enabled):
        self.node = MIC_NODE if enabled else None
        self.lock = threading.Lock()
        self.sounds = self.voice = None
        self.source = None  # the real mic's PipeWire node name

    def start(self):
        if self.node:
            self._kill_stale()
            self.sounds = subprocess.Popen([
                "pw-loopback", "--name", "kitty-cam-sounds",
                f'--capture-props=media.class=Audio/Sink node.name={SINK_NODE} node.description="{SINK_LABEL}"',
                f'--playback-props=media.class=Audio/Source node.name={MIC_NODE} node.description="{MIC_LABEL}"',
            ], stdout=subprocess.DEVNULL)
            self.use(None)

    def use(self, label):
        """Put the real mic whose description is `label` (the page's mic) into Kitty Cam Mic; None or no match:
        the default source."""
        if not self.node:
            return
        found = sources()
        name = next((s["name"] for s in found if label and s["description"] == label), None)
        if name is None:
            default = default_source()
            name = default if any(s["name"] == default for s in found) else (found[0]["name"] if found else None)
        with self.lock:
            if name == self.source and self.voice and self.voice.poll() is None:
                return
            self._stop_voice()
            self.source = name
            if name is None:
                log(f"no mic to put into {MIC_LABEL}")
                return
            log(f"{MIC_LABEL}: {next((s['description'] for s in found if s['name'] == name), name)} + the soundboard")
            self.voice = subprocess.Popen([
                "pw-loopback", "--name", "kitty-cam-voice",
                f"--capture-props=node.name={VOICE_NODE} target.object={name} node.dont-reconnect=true node.passive=true",
                f"--playback-props=node.name={VOICE_NODE}_out target.object={SINK_NODE} node.dont-reconnect=true",
            ], stdout=subprocess.DEVNULL)

    def _stop_voice(self):
        proc, self.voice = self.voice, None
        _end(proc)

    @staticmethod
    def _kill_stale():
        """Stop loopbacks left by a kitty-cam that was killed outright: a second Kitty Cam Mic."""
        marks = (f"node.name={SINK_NODE} ".encode(), f"node.name={VOICE_NODE} ".encode())
        for proc in Path("/proc").iterdir():
            if not proc.name.isdigit():
                continue
            try:
                cmd = (proc / "cmdline").read_bytes()
                if cmd.startswith(b"pw-loopback\0") and any(m in cmd for m in marks):
                    log(f"stopping a leftover mic loopback ({proc.name})")
                    os.kill(int(proc.name), signal.SIGTERM)
            except (OSError, ValueError):
                continue

    def status(self):
        return {"node": self.node, "source": self.source} if self.node else None

    def close(self):
        with self.lock:
            self._stop_voice()
            proc, self.sounds = self.sounds, None
            _end(proc)


def _end(proc):
    if proc is None:
        return
    proc.terminate()
    try:
        proc.wait(3)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
