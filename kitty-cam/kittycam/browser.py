"""The page's own Chromium window (or a headless Chromium), on its own profile: the flags below apply, and
the camera/mic permission is remembered."""
import shutil
import subprocess

from .paths import CACHE, CONFIG


def features(*extra):
    """Chromium keeps only the last --enable-features, and Arch's /usr/bin/chromium puts chromium-flags.conf
    first, so ours has to carry that file's features too."""
    have = []
    try:
        for word in (CONFIG / "chromium-flags.conf").read_text().split():
            if word.startswith("--enable-features="):
                have += word.split("=", 1)[1].split(",")
    except OSError:
        pass
    return have + [f for f in extra if f not in have]


def find_chromium():
    for name in ("chromium", "chromium-browser", "google-chrome-stable", "google-chrome"):
        if shutil.which(name):
            return name
    return None


def launch(url, headless):
    """Start Chromium on `url`; None when there is no Chromium."""
    exe = find_chromium()
    if not exe:
        return None
    args = [exe, f"--user-data-dir={CACHE / 'chromium'}", "--no-first-run", "--no-default-browser-check",
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
