import QtQuick
import Quickshell.Hyprland
import qs
import qs.components

// Mirrors hyprland/workspaces: 5 persistent workspaces, specials shown, "{icon} {windows}".
Row {
    id: root

    readonly property var persistent: [1, 2, 3, 4, 5]

    readonly property var windowIcons: [
        [/^(kitty|Alacritty|konsole)$/, 0xf018d],
        [/^(code|codium)$/, 0xf0a1e],
        [/^(mousepad|obsidian|Obsidian)$/, 0xf14e7],
        [/^(firefox|Firefox)$/, 0xf0239],
        [/^(chromium|chrome|Chromium)$/, 0xf268],
        [/^(nemo|Nemo)$/, 0xf07b],
        [/^(org\.inkscape\.Inkscape)$/, 0xee72],
        [/^(org\.kde\.Kdenlive)$/, 0xf0381],
        [/^(org\.musicbrainz\.Picard)$/, 0xf001],
        [/^(vlc|VLC|mpv)$/, 0xf057c],
        [/^(blueman-manager)$/, 0xf00af],
        [/^(pavucontrol|Pavucontrol)$/, 0xf1542],
        [/^(nm-connection-editor)$/, 0xf043b],
        [/^(nwg-look|qt5ct|qt6ct|qdbusviewer)$/, 0xf0493]
    ]

    // One entry per button: {id, name, ws} where ws is null for a not-yet-created persistent workspace.
    readonly property var entries: {
        const live = Hyprland.workspaces.values;
        const out = persistent.map(id => ({
                    id: id,
                    name: String(id),
                    ws: live.find(w => w.id === id) ?? null
                }));
        for (const w of live) {
            if (!persistent.includes(w.id))
                out.push({
                    id: w.id,
                    name: w.name,
                    ws: w
                });
        }
        // Normal workspaces by id, specials (negative ids) at the end.
        return out.sort((a, b) => (a.id < 0) - (b.id < 0) || (a.id < 0 ? a.name.localeCompare(b.name) : a.id - b.id));
    }

    function windowIcon(toplevel) {
        const cls = toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "";
        const hit = windowIcons.find(r => r[0].test(cls));
        return Theme.g(hit ? hit[1] : 0xf02a0);
    }

    function activate(entry) {
        if (entry.id < 0) {
            const name = entry.name.replace(/^special:/, "");
            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.workspace.toggle_special("${name}")` : `togglespecialworkspace ${name}`);
        } else {
            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = ${entry.id} })` : `workspace ${entry.id}`);
        }
    }

    // #workspaces-group padding 0 4px + #workspaces padding 0 6px
    leftPadding: 10
    rightPadding: 10
    height: Theme.barHeight

    Component.onCompleted: Hyprland.refreshToplevels()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle"].includes(event.name))
                Hyprland.refreshToplevels();
        }
    }

    Repeater {
        model: root.entries

        Rectangle {
            id: button

            required property var modelData
            readonly property HyprlandWorkspace ws: modelData.ws
            readonly property var toplevels: ws ? ws.toplevels.values : []
            readonly property bool special: modelData.id < 0
            readonly property bool active: ws !== null && (special ? ws.active || Hyprland.focusedWorkspace === ws : Hyprland.focusedWorkspace === ws)
            readonly property bool urgent: ws?.urgent ?? false
            readonly property bool empty: toplevels.length === 0
            readonly property int hPad: active ? 12 : 4

            readonly property string icon: Theme.g(urgent ? 0xf09f5 : active ? 0xf0baf : special ? 0xf1042 : empty ? 0xf09de : 0xf02a0)

            readonly property color fgColor: {
                if (hover.containsMouse)
                    return active ? Theme.on_primary : Theme.primary;
                if (active)
                    return Theme.on_primary;
                if (urgent)
                    return Theme.error_container;
                if (special)
                    return Theme.tertiary_fixed;
                if (empty)
                    return Theme.outline_variant;
                return Theme.on_surface;
            }

            // margin: 3px 2px
            y: 3
            height: Theme.barHeight - 6
            // GTK min-width is content-box: it applies before the padding
            readonly property real contentWidth: Math.max(28, label.implicitWidth + 10)

            width: contentWidth + 2 * hPad + 4
            radius: height / 2
            color: "transparent"

            Rectangle {
                id: pill
                x: 2
                width: parent.width - 4
                height: parent.height
                radius: height / 2
                color: button.active ? Theme.primary : hover.containsMouse ? Theme.surface_container_highest : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 400
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.25, 0.46, 0.45, 0.94, 1, 1]
                    }
                }
            }

            Text {
                id: label
                // label margin-left 2px, margin-right 8px inside the button padding
                x: pill.x + button.hPad + (button.contentWidth - (implicitWidth + 10)) / 2 + 2
                anchors.verticalCenter: parent.verticalCenter
                text: button.icon + " " + button.toplevels.map(t => root.windowIcon(t)).reverse().join(" ")
                color: button.fgColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.workspacePx
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation {
                        duration: 400
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.25, 0.46, 0.45, 0.94, 1, 1]
                    }
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.Bezier
                    easing.bezierCurve: [0.25, 0.46, 0.45, 0.94, 1, 1]
                }
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activate(button.modelData)
            }
        }
    }
}
