import sys


def log(msg):
    print(f"kitty-cam: {msg}", file=sys.stderr, flush=True)
