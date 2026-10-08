import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// The cat avatar sitting in the top right corner of every visible kitty window, all with the same
// moods (Pet). Reactions to a command only reach the cat of the window it ran in.
// Click-through layer surfaces that follow their window: Hyprland's toplevel geometry is refreshed on
// its events and polled while a kitty is shown (dragging or resizing with the mouse sends no event):
// every 150 ms at rest, every 10 ms (one 100 Hz frame) while a window's geometry keeps changing.
// Hyprland reports where an animated window will end up, so a single jump (a tiled move) is followed
// with a spring like its own; a stream of updates (a drag) is followed directly.
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

    // True while a kitty's geometry changed within the last 300 ms.
    property bool moving: false
    readonly property string geometry: kitties.map(t => `${t.lastIpcObject?.at}/${t.lastIpcObject?.size}`).join(" ")
    onGeometryChanged: {
        moving = true;
        still.restart();
    }

    Timer {
        id: still
        interval: 300
        onTriggered: root.moving = false
    }

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
        interval: root.moving ? 10 : 150
        repeat: true
        running: Pet.kittyShown && root.kitties.some(t => root.shown(t))
        onTriggered: root.moving ? Hyprland.refreshToplevels() : root.refresh()
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

            // The window's top right corner, relative to its monitor: where Hyprland reports it (the
            // end of any animation), and where the cat follows it.
            readonly property var target: [(ipc?.at?.[0] ?? 0) - (monitor?.x ?? 0) + (ipc?.size?.[0] ?? 0), (ipc?.at?.[1] ?? 0) - (monitor?.y ?? 0)]
            property real cornerX
            property real cornerY
            property real vx: 0
            property real vy: 0
            property real lastX
            property real lastY
            property double lastChange: 0
            Component.onCompleted: {
                lastX = target[0];
                lastY = target[1];
                snap();
            }

            function snap() {
                spring.running = false;
                cornerX = target[0];
                cornerY = target[1];
                vx = vy = 0;
            }

            onTargetChanged: {
                if (target[0] === lastX && target[1] === lastY)
                    return;
                lastX = target[0];
                lastY = target[1];
                const now = Date.now();
                const streaming = now - lastChange < 100;
                lastChange = now;
                if (streaming || !wanted)
                    snap();
                else
                    spring.running = true;
            }
            onWantedChanged: snap()

            // Critically damped, like the `easy` spring of Hyprland's window animation (mass 1,
            // stiffness 878.5, dampening 59.29).
            FrameAnimation {
                id: spring
                onTriggered: {
                    // Substeps of at most 4 ms keep the integration stable through a slow frame.
                    const k = 878.5, c = 59.29, total = Math.min(frameTime, 0.1);
                    const steps = Math.ceil(total / 0.004), dt = total / steps;
                    let x = win.cornerX, y = win.cornerY, vx = win.vx, vy = win.vy;
                    for (let i = 0; i < steps; i++) {
                        vx += (k * (win.target[0] - x) - c * vx) * dt;
                        vy += (k * (win.target[1] - y) - c * vy) * dt;
                        x += vx * dt;
                        y += vy * dt;
                    }
                    win.vx = vx;
                    win.vy = vy;
                    win.cornerX = x;
                    win.cornerY = y;
                    if (Math.abs(win.target[0] - win.cornerX) < 0.5 && Math.abs(win.target[1] - win.cornerY) < 0.5 && Math.abs(win.vx) + Math.abs(win.vy) < 10)
                        win.snap();
                }
            }

            visible: wanted
            anchors.top: true
            anchors.left: true
            margins.left: Math.round(cornerX) - root.size - root.inset - root.side
            margins.top: Math.round(cornerY) + root.inset - root.headroom
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
                    voice: Pet.voice

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
