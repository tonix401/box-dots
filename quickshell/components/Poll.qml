import QtQuick
import Quickshell
import Quickshell.Io

// Runs `command` every `interval` ms (0 = only once) and exposes its trimmed stdout.
// `act(cmd)` runs a shell command and refreshes as soon as it exits, standing in for
// the `pkill -RTMIN+N waybar` refresh signals.
Scope {
    id: root

    required property var command
    property int interval: 0
    property string output: ""

    function refresh() {
        proc.running = true;
    }

    function act(cmd) {
        action.command = ["sh", "-c", cmd];
        action.running = true;
    }

    Process {
        id: proc
        command: root.command
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.output = text.trim()
        }
    }

    Process {
        id: action
        onExited: root.refresh()
    }

    Timer {
        interval: Math.max(root.interval, 1)
        running: root.interval > 0
        repeat: true
        onTriggered: root.refresh()
    }
}
