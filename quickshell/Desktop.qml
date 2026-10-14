pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Whether the desktop widgets (calendar, todo list, habit tracker) are shown. Driven by the
// `widgets` IPC target in shell.qml; remembered across restarts. Independently of that they step
// aside while the desktop is `covered`: a tiled (not floating) window is on the workspace shown, or
// on the special workspace open over it. Floating windows leave them up.
Singleton {
    id: root

    property bool widgetsShown: true

    // Floating comes from Hyprland's client list (lastIpcObject), refreshed after its events.
    readonly property bool covered: Hyprland.toplevels.values.some(t => {
        const ws = t.workspace, ipc = t.lastIpcObject;
        if (!ws || !ipc || ipc.floating !== false || ipc.hidden)
            return false;
        return ws.name.startsWith("special:") ? t.monitor?.lastIpcObject?.specialWorkspace?.name === ws.name : ws.active;
    })

    function setShown(shown) {
        widgetsShown = shown;
        state.setText(JSON.stringify({
            widgetsShown: shown
        }) + "\n");
    }

    function toggle() {
        setShown(!widgetsShown);
    }

    // Events come in bursts (opening a window sends several); refresh once they stop.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 60
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
        }
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
    }

    FileView {
        id: state
        path: Quickshell.statePath("desktop.json")
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                root.widgetsShown = JSON.parse(text()).widgetsShown ?? true;
            } catch (e) {}
        }
    }
}
