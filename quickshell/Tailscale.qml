pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared tailscale state for the bar and the start menu, so toggling in one updates the other.
// Follows tailscaled's IPN bus (`tailscale debug watch-ipn`), which prints a pretty-printed
// notification whenever the backend state changes, so terminal `tailscale up/down` shows too.
Singleton {
    id: root

    property int state: -1 // ipn.State; 6 = Running (-1 until the first notification)
    readonly property string status: state < 0 ? "" : up ? "up" : "down"
    readonly property bool up: state === 6

    function toggle() {
        Quickshell.execDetached(["tailscale", up ? "down" : "up"]);
    }

    Process {
        id: watch
        command: ["tailscale", "debug", "watch-ipn", "--initial"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const m = /^\t"State": (\d+)/.exec(line);
                if (m)
                    root.state = parseInt(m[1]);
            }
        }
        // tailscaled restarted or isn't up yet: try again shortly.
        onExited: {
            root.state = -1;
            retry.start();
        }
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: watch.running = true
    }
}
