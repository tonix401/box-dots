"""The local web server between the page and the camera, on 127.0.0.1 only.

    GET  /            web/index.html, and every other file under web/ as it is
    GET  /vendor/…    MediaPipe, from the download cache (assets.py)
    GET  /theme       the theme colours (theme.py), {} without one
    GET  /status      the camera and the page's own figures, to check a running instance from outside
    POST /frame       one YUV 4:2:0 frame for the camera: 204 written, 503 not (no camera, device error)
    GET  /sounds      the soundboard's pads (sounds.py); GET /sounds/<file> one of its files
    POST /sounds/<file>  add a dropped file (the body); DELETE /sounds/<file> remove one
    PUT  /sounds.json the pads' order, names, volumes and effects, as the page edited them
    POST /mic         {"label": …}: the mic picked in the page, which Kitty Cam Mic then carries (audio.py)
    GET  /events      Server-Sent Events for the page: "play <file>", "stop" (from `kitty-cam --play`)
    POST /play        {"pad": "<slot or name>" | "stop"}: from `kitty-cam --play`, never from a browser

Only the page itself may use it: any web page in the browser can send a POST to 127.0.0.1 (it just can't
read the answer), so frames are taken only with the page's own Origin, which browsers always send on a
POST; and requests are answered only under our own host name, so a DNS-rebound name can't read anything.
/play is the one request from outside the page (the CLI, a key binding): it must come with no Origin and an
`X-Kitty-Cam: play` header. A web page can't send that: a custom header cross-origin needs a CORS preflight,
which this server never grants.
"""
import json
import queue
import threading
import time
from urllib.parse import unquote
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import audio, sounds, theme
from .assets import VENDOR, VENDOR_DIR
from .paths import WEB

TYPES = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript",
         ".mjs": "text/javascript", ".json": "application/json", ".svg": "image/svg+xml",
         ".wasm": "application/wasm", ".task": "application/octet-stream",
         ".mp3": "audio/mpeg", ".ogg": "audio/ogg", ".oga": "audio/ogg", ".opus": "audio/ogg", ".wav": "audio/wav",
         ".flac": "audio/flac", ".m4a": "audio/mp4", ".aac": "audio/aac", ".webm": "audio/webm"}


def web_file(path):
    """The file under web/ for a URL path, or None (missing, or outside web/)."""
    rel = "index.html" if path == "/" else path.lstrip("/")
    f = (WEB / rel).resolve()
    return f if f.is_file() and f.is_relative_to(WEB) else None


def make_server(port, camera, mic, theme_path):
    events = sounds.Events()

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

        def send_json(self, value):
            self.send(200, json.dumps(value).encode(), TYPES[".json"])

        def trusted(self, post):
            hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
            if self.headers.get("Host") not in hosts:
                return False
            origin = self.headers.get("Origin")
            if origin is None:
                return not post
            return origin in {"http://" + h for h in hosts}

        def from_cli(self):
            """The CLI's /play: no browser sends this without a preflight (see the docstring)."""
            return (self.headers.get("Host") in {f"127.0.0.1:{port}", f"localhost:{port}"}
                    and self.headers.get("Origin") is None and self.headers.get("X-Kitty-Cam") == "play")

        def body(self, limit=sounds.MAX_BYTES):
            n = int(self.headers.get("Content-Length", 0))
            if n > limit:
                raise ValueError("too big")
            return self.rfile.read(n)

        def sound_name(self):
            return unquote(self.path.split("?")[0][len("/sounds/"):])

        def stream_events(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            q = events.listen()
            try:
                self.wfile.write(b": hello\n\n")
                self.wfile.flush()
                while True:
                    try:
                        msg = q.get(timeout=15)
                        self.wfile.write(f"data: {msg}\n\n".encode())
                    except queue.Empty:
                        self.wfile.write(b": keep-alive\n\n")
                    self.wfile.flush()
            except OSError:
                pass  # the page went away
            finally:
                events.leave(q)

        def do_GET(self):
            if not self.trusted(post=False):
                return self.send(403, b"forbidden")
            path = self.path.split("?")[0]
            if path == "/status":
                return self.send_json({"camera": camera.node, "frames": camera.frames, "page": camera.stats,
                                       "drawn_to_helper_ms": round(camera.arrival_ms, 1), "mic": mic.status()})
            if path == "/events":
                return self.stream_events()
            if path == "/sounds":
                return self.send_json({"pads": sounds.pads(), "sink": audio.SINK_LABEL if mic.node else None})
            if path.startswith("/sounds/"):
                f = sounds.audio_file(self.sound_name())
                if f is None:
                    return self.send(404, b"not found")
                return self.send(200, f.read_bytes(), TYPES.get(f.suffix.lower(), "application/octet-stream"))
            if path == "/theme":
                return self.send_json(theme.load(theme_path))
            if path.startswith("/vendor/"):
                name = path[len("/vendor/"):]
                if name in VENDOR:
                    f = VENDOR_DIR / name
                    return self.send(200, f.read_bytes(), TYPES.get(f.suffix, "application/octet-stream"))
                return self.send(404, b"not found")
            f = web_file(path)
            if f is None:
                return self.send(404, b"not found")
            self.send(200, f.read_bytes(), TYPES.get(f.suffix, "application/octet-stream"))

        def do_POST(self):
            if self.path == "/play" and self.from_cli():
                return self.play()
            if not self.trusted(post=True):
                return self.send(403, b"forbidden")
            try:
                if self.path.startswith("/sounds/"):
                    name = sounds.add(self.sound_name(), self.body())
                    return self.send_json({"file": name})
                if self.path == "/mic":
                    label = json.loads(self.body(4096) or b"{}").get("label")
                    threading.Thread(target=mic.use, args=(label,), daemon=True).start()
                    return self.send(204)
            except ValueError as e:
                return self.send(400, str(e).encode())
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
            self.send(204 if camera.write(body) else 503)


        def play(self):
            try:
                which = str(json.loads(self.body(4096) or b"{}").get("pad", ""))
            except ValueError:
                return self.send(400, b"bad request")
            if which == "stop":
                msg = "stop"
            else:
                pad = sounds.find(which)
                if pad is None:
                    return self.send(404, f"no pad {which!r}".encode())
                msg = f"play {pad['file']}"
            if not events.send(msg):
                return self.send(503, b"the page isn't open")
            self.send(204)

        def do_PUT(self):
            if not self.trusted(post=True):
                return self.send(403, b"forbidden")
            if self.path != "/sounds.json":
                return self.send(404, b"not found")
            try:
                sounds.save(json.loads(self.body(1024 * 1024)).get("pads"))
            except (ValueError, AttributeError) as e:
                return self.send(400, str(e).encode())
            self.send(204)

        def do_DELETE(self):
            if not self.trusted(post=True):
                return self.send(403, b"forbidden")
            if not self.path.startswith("/sounds/"):
                return self.send(404, b"not found")
            self.send(204 if sounds.remove(self.sound_name()) else 404)

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)
