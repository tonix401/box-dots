pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components

// Streamer mode: true while OBS is running, so the bar and menus mask the SSID, IP,
// user@host and device names that would otherwise end up on stream, and shell.qml hides the
// desktop widgets.
Singleton {
    // pgrep prints the pid, or nothing. Its window shows up at once; the poll catches it in the tray.
    readonly property bool active: ToplevelManager.toplevels.values.some(t => t.appId === "com.obsproject.Studio") || obs.output !== ""

    // `value` normally, asterisks while OBS runs (empty values stay empty).
    function mask(value) {
        return active && value ? "*****" : value;
    }

    // Only polled where OBS is installed.
    Poll {
        id: installed
        command: ["sh", "-c", "command -v obs"]
    }

    Poll {
        id: obs
        command: installed.output ? ["pgrep", "-x", "obs"] : ["true"]
        interval: installed.output ? 2000 : 0
    }
}
