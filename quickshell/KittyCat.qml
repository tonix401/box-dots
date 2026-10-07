import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// The cat avatar sitting in the top right corner of every visible kitty window, all with the same
// moods (Pet). Reactions to a command only reach the cat of the window it ran in.
// Click-through layer surfaces that follow their window: Hyprland's toplevel geometry is refreshed on
// its events, and every second while a kitty is shown (a floating resize sends no event).
// `qs ipc call cat kitty` turns them off and on. Single monitor: the windows don't bind `screen`
// (switching it on a shown window toggled `visible` in a binding loop); margins are still taken
// relative to the window's monitor.
Scope {
    id: root

    readonly property int size: 120
    readonly property int inset: 8 // from the window's top and right edges
    // Transparent room around the cat inside its surface, which would clip it otherwise: squishing
    // widens it to ~1.2x (with the spring's overshoot), hops and the rebound stretch it upwards.
    readonly property int side: Math.round(size * 0.17)
    readonly property int headroom: Math.round(size * 0.32)

    readonly property var kitties: Hyprland.toplevels.values.filter(t => t.lastIpcObject?.class === "kitty")

    function refresh() {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
    }

    // A window is shown when its workspace is the active one on its monitor, or the special
    // workspace open there; on a workspace with a fullscreen window, only if it is that window.
    function shown(t) {
        const ws = t.workspace, ipc = t.lastIpcObject;
        if (!ws || !ipc?.at || ipc.hidden)
            return false;
        const special = ws.name.startsWith("special:");
        const visibleWs = special ? t.monitor?.lastIpcObject?.specialWorkspace?.name === ws.name : ws.active;
        return visibleWs && (!ws.hasFullscreen || (ipc.fullscreen ?? 0) > 0);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            settle.restart();
        }
    }

    // Events come in bursts (open = several); refresh once they stop.
    Timer {
        id: settle
        interval: 60
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        repeat: true
        running: Pet.kittyShown && root.kitties.some(t => root.shown(t))
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    Variants {
        model: Pet.kittyShown ? root.kitties : []

        PanelWindow {
            id: win

            required property var modelData
            readonly property var ipc: modelData.lastIpcObject
            readonly property var monitor: modelData.monitor
            readonly property bool wanted: root.shown(modelData)

            visible: wanted
            anchors.top: true
            anchors.left: true
            margins.left: (ipc?.at?.[0] ?? 0) - (monitor?.x ?? 0) + (ipc?.size?.[0] ?? 0) - root.size - root.inset - root.side
            margins.top: (ipc?.at?.[1] ?? 0) - (monitor?.y ?? 0) + root.inset - root.headroom
            implicitWidth: root.size + 2 * root.side
            implicitHeight: root.headroom + root.size * 1.05
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-kitty-cat"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {} // clicks go to the terminal
            color: "transparent"

            // Created while shown only, so hidden cats don't animate.
            Loader {
                active: win.wanted
                x: root.side
                y: root.headroom
                sourceComponent: Cat {
                    id: cat
                    implicitWidth: root.size
                    expression: Pet.expressionFor(win.modelData.address)
                    squished: Pet.squishedFor(win.modelData.address)

                    Connections {
                        target: Pet
                        function onActed(motion, count, target) {
                            if (target === "*" || target === win.modelData.address)
                                cat.act(motion, count);
                        }
                    }
                }
            }
        }
    }
}
