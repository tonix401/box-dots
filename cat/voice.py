#!/usr/bin/env python3
"""Sing-along for the cats (SPEC.md, "Singing"): listens to what the speakers play and prints how the
cat's mouth should move, one line per 16 ms frame: `active open wide round` (active 0/1, the rest 0..1).
Pet.qml runs it and hands each line to the cats (CatEngine.voice).

It only listens while something plays: it follows playback streams with `pactl subscribe`, and records
the default sink's monitor with pw-record only while one of them is uncorked. Each line is held back by
the default sink's own latency (PipeWire's Latency param, ~145 ms on the Bluetooth headset), so the
mouth moves when you hear the sound rather than when it is sent to the speakers.

The voice: the centre of the stereo image with the sides subtracted, per frequency (vocals are mixed
centre, most instruments wide), 150-4000 Hz. Its loudness against the loudest recent frame opens the
mouth, its periodicity (voiced sound has a pitch, drums don't) weighs that, and the vowel's formants
pick the shape, from the energy in three bands (low 150-450, mid 550-1300, high 1700-3500 Hz): a strong
high band against the mid one is "ee"/"e" (wide), a weak mid band against the low one is "oo"
(round), anything else "ah"/"o" (open). Checked on synthetic vowels at 120 and 220 Hz pitch.

  voice.py [--offset MS]    # added to the measured latency; negative moves the mouth earlier
  voice.py --debug          # also print the raw features to stderr
"""
import argparse
import json
import math
import os
import select
import subprocess
import sys
import time
from collections import deque

RATE = 16000
HOP = 256  # samples per frame: 16 ms
WIN = 512  # analysis window: 32 ms
GATE = -62.0  # dBFS: quieter than this is silence
ACTIVE_HOLD = 0.6  # s: the sing mouth stays after the last voiced frame
CAPTURE_LAG = 0.03  # s: a frame's centre was sent to the speakers about this long before we see it


def clip(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def playing():
    """Whether any playback stream is uncorked (our own capture is a record stream, not counted)."""
    try:
        out = subprocess.run(["pactl", "-f", "json", "list", "sink-inputs"], capture_output=True, text=True, timeout=3).stdout
        return any(not s.get("corked") for s in json.loads(out or "[]"))
    except (subprocess.SubprocessError, ValueError, OSError):
        return False


def sink_latency():
    """The default sink's own latency in seconds, from PipeWire (0 if it can't be found)."""
    try:
        objs = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5).stdout)
    except (subprocess.SubprocessError, ValueError, OSError):
        return 0.0
    name = None
    for o in objs:
        if o.get("type") == "PipeWire:Interface:Metadata" and (o.get("props") or {}).get("metadata.name") == "default":
            for m in o.get("metadata") or []:
                if m.get("key") == "default.audio.sink":
                    v = m.get("value")
                    name = (json.loads(v) if isinstance(v, str) else v or {}).get("name")
    for o in objs:
        info = o.get("info") or {}
        if name and (info.get("props") or {}).get("node.name") == name:
            lat = [p.get("maxNs", 0) for p in (info.get("params") or {}).get("Latency", []) if p.get("direction") == "Input"]
            return max(lat, default=0) / 1e9
    return 0.0


class Mouth:
    """Turns stereo frames into mouth shapes."""

    def __init__(self, debug):
        import numpy as np
        self.np = np
        self.debug = debug
        self.window = np.hanning(WIN)
        self.norm = 2 / (WIN * (self.window ** 2).sum())  # Parseval: band power -> mean square, so dB is dBFS
        freqs = np.fft.rfftfreq(WIN, 1 / RATE)
        self.band = (freqs >= 150) & (freqs <= 4000)
        self.lags = slice(RATE // 400, RATE // 80)  # pitch periods of 80-400 Hz
        self.buf = np.zeros((WIN, 2))
        self.peak = GATE
        self.bands = [(freqs >= lo) & (freqs < hi) for lo, hi in ((150, 450), (550, 1300), (1700, 3500))]
        self.last_voice = -1e9
        self.shape = [0.0, 0.0, 0.0]

    def frame(self, chunk, now):
        np = self.np
        self.buf = np.concatenate([self.buf[HOP:], chunk])
        mid = np.fft.rfft((self.buf[:, 0] + self.buf[:, 1]) / 2 * self.window)
        side = np.fft.rfft((self.buf[:, 0] - self.buf[:, 1]) / 2 * self.window)
        mag = np.maximum(np.abs(mid) - np.abs(side), 0)
        mag[~self.band] = 0
        power = mag ** 2
        energy = power.sum()
        db = 10 * math.log10(energy * self.norm + 1e-12)
        # Periodicity: the autocorrelation's highest peak at a pitch period, against lag 0.
        ac = np.fft.irfft(power)
        voiced = clip((ac[self.lags].max() / (ac[0] + 1e-12) - 0.25) / 0.45) if energy > 0 else 0.0
        # The loudest recent frame opens the mouth fully; it fades ~8 dB a second, following the song.
        self.peak = max(db, self.peak - 0.13, GATE)
        loud = clip((db - self.peak + 18) / 15) * (0.35 + 0.65 * voiced) if db > GATE else 0.0
        low, mid, high = (10 * math.log10(power[b].sum() + 1e-12) for b in self.bands)
        wide = clip((high - mid + 22) / 14)
        rnd = clip((low - mid - 3) / 10) * (1 - wide)
        target = [loud * (1 - 0.75 * rnd - 0.6 * wide), loud * wide * 0.9, loud * rnd * 0.9]
        # Opens quickly, closes a little slower: syllables stay readable without chattering.
        self.shape = [s + (g - s) * (0.75 if g > s else 0.4) for s, g in zip(self.shape, target)]
        if loud > 0.2:
            self.last_voice = now
        if self.debug:
            print(f"db {db:6.1f} peak {self.peak:6.1f} voiced {voiced:.2f} mid-low {mid - low:5.1f} high-mid {high - mid:5.1f} loud {loud:.2f}", file=sys.stderr)
        active = 1 if now - self.last_voice < ACTIVE_HOLD else 0
        return active, self.shape


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--offset", type=float, default=0, help="ms added to the measured latency")
    ap.add_argument("--debug", action="store_true", help="print the raw features to stderr")
    args = ap.parse_args()

    sub = subprocess.Popen(["pactl", "subscribe"], stdout=subprocess.PIPE)
    rec = None
    mouth = None
    pending = b""
    queue = deque()  # (due, line)
    last = None
    check_at = 0.0
    delay = 0.0

    def say(line):
        nonlocal last
        if line != last:
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
            last = line

    def stop():
        nonlocal rec
        if rec:
            rec.terminate()
            rec.wait()
            rec = None
        queue.clear()
        say("0 0 0 0")

    try:
        say("0 0 0 0")
        while True:
            fds = [sub.stdout] + ([rec.stdout] if rec else [])
            ready, _, _ = select.select(fds, [], [], 0.01 if queue else 1.0)
            now = time.monotonic()
            if sub.stdout in ready:
                events = os.read(sub.stdout.fileno(), 65536)
                if not events:
                    return 1  # pactl went away: Quickshell restarts us
                if b"sink-input" in events:
                    check_at = min(check_at, now + 0.2)
                if b"on server" in events and rec:  # the default sink may have changed: listen to the new one
                    stop()
                    check_at = now
            if now >= check_at:
                check_at = now + 5
                if playing():
                    if not rec:
                        delay = max(0.0, sink_latency() + args.offset / 1000 - CAPTURE_LAG)
                        mouth = mouth or Mouth(args.debug)
                        rec = subprocess.Popen(["pw-record", "-P", "{ stream.capture.sink=true node.name=cat-voice }", "--rate", str(RATE),
                                                "--channels", "2", "--format", "s16", "--latency", str(HOP), "-"],
                                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                        pending = b""
                elif rec:
                    stop()
            if rec and rec.stdout in ready:
                data = os.read(rec.stdout.fileno(), 65536)
                if not data:
                    stop()
                    check_at = now + 1
                else:
                    pending += data
                    step = HOP * 4  # 2 channels of 16 bit
                    n = len(pending) // step
                    for i in range(n):  # several frames in one read: the last one is now, the others earlier
                        chunk = mouth.np.frombuffer(pending[i * step:(i + 1) * step], dtype="<i2").reshape(-1, 2) / 32768.0
                        t = now - (n - 1 - i) * HOP / RATE
                        active, (o, w, r) = mouth.frame(chunk, t)
                        queue.append((t + delay, f"{active} {o:.2f} {w:.2f} {r:.2f}"))
                    pending = pending[n * step:]
            while queue and queue[0][0] <= now:
                say(queue.popleft()[1])
    except (BrokenPipeError, KeyboardInterrupt):
        return 0
    finally:
        if rec:
            rec.terminate()
        sub.terminate()


if __name__ == "__main__":
    sys.exit(main())
