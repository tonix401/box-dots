"""The local web server between the page and the camera, on 127.0.0.1 only.

    GET  /            web/index.html, and every other file under web/ as it is
    GET  /vendor/…    MediaPipe, from the download cache (assets.py)
    GET  /theme       the theme colours (theme.py), {} without one
    GET  /status      the camera and the page's own figures, to check a running instance from outside
    POST /frame       one YUV 4:2:0 frame for the camera: 204 written, 503 not (no camera, device error)

Only the page itself may use it: any web page in the browser can send a POST to 127.0.0.1 (it just can't
read the answer), so frames are taken only with the page's own Origin, which browsers always send on a
POST; and requests are answered only under our own host name, so a DNS-rebound name can't read anything.
"""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import theme
from .assets import VENDOR, VENDOR_DIR
from .paths import WEB

TYPES = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript",
         ".mjs": "text/javascript", ".json": "application/json", ".svg": "image/svg+xml",
         ".wasm": "application/wasm", ".task": "application/octet-stream"}


def web_file(path):
    """The file under web/ for a URL path, or None (missing, or outside web/)."""
    rel = "index.html" if path == "/" else path.lstrip("/")
    f = (WEB / rel).resolve()
    return f if f.is_file() and f.is_relative_to(WEB) else None


def make_server(port, camera, theme_path):
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

        def do_GET(self):
            if not self.trusted(post=False):
                return self.send(403, b"forbidden")
            path = self.path.split("?")[0]
            if path == "/status":
                return self.send_json({"camera": camera.node, "frames": camera.frames, "page": camera.stats,
                                       "drawn_to_helper_ms": round(camera.arrival_ms, 1)})
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
            if not self.trusted(post=True):
                return self.send(403, b"forbidden")
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

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)
