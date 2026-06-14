#!/usr/bin/env python3
"""Generate cliphist image thumbnails in parallel."""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed


def generate_thumb(entry: str, thumb_dir: str) -> None:
    id_, _, _ = entry.partition("\t")
    thumb = os.path.join(thumb_dir, f"{id_}.png")
    if os.path.exists(thumb):
        return
    try:
        decoded = subprocess.run(
            ["cliphist", "decode"],
            input=entry.encode(),
            capture_output=True,
        )
        if decoded.returncode != 0:
            return
        subprocess.run(
            ["convert", "-", "-thumbnail", "72x72^", "-gravity", "center", "-extent", "72x72", thumb],
            input=decoded.stdout,
            capture_output=True,
        )
    except Exception:
        pass


def main() -> None:
    thumb_dir = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("THUMB_DIR", "/tmp/cliphist-thumbs")
    os.makedirs(thumb_dir, exist_ok=True)

    entries = [
        line.rstrip("\n")
        for line in sys.stdin
        if "[[ binary data" in line
    ]

    if not entries:
        return

    with ThreadPoolExecutor() as pool:
        futures = {pool.submit(generate_thumb, e, thumb_dir): e for e in entries}
        for f in as_completed(futures):
            f.result()


if __name__ == "__main__":
    main()
