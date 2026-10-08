pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Streamer mode: true while OBS is running, so the bar and menus mask the SSID, IP,
// user@host and device names that would otherwise end up on stream, and shell.qml hides the
// desktop widgets.
Singleton {
    readonly property bool active: obs.output === "1"

    // `value` normally, asterisks while OBS runs (empty values stay empty).
    function mask(value) {
        return active && value ? "*****" : value;
    }

    Poll {
        id: obs
        command: ["sh", "-c", "pgrep -x obs >/dev/null && echo 1 || echo 0"]
        interval: 2000
    }
}
