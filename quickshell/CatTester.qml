import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// A panel in the bottom right corner for triggering everything the cats do by hand: every reaction
// (directly or through `qs ipc` like the fish hook, on every cat or only the focused window's), pinning
// each expression, the motions and the squish, marking the focused window busy (as a running command
// would), and faking the context the base mood comes from.
// Opened by SUPER + SHIFT + C (hypr/keybinds.lua) or `qs ipc call cat tester`; closing it lifts the pin and the fakes again.
PanelWindow {
    id: root

    property bool viaIpc: false
    property bool onlyFocused: false // react only in the focused window, as a command in it would
    // The panel takes no focus, so this stays the window last used.
    readonly property var focused: Hyprland.activeToplevel
    property var expressions: [] // from the rig, so new ones show up here by themselves
    readonly property int pad: 16

    function react(event) {
        if (onlyFocused && !focused)
            return;
        if (onlyFocused && viaIpc)
            Quickshell.execDetached(["qs", "ipc", "call", "cat", "reactPid", event, String(focused.lastIpcObject?.pid ?? 0)]);
        else if (onlyFocused)
            Pet.react(event, [focused.address]);
        else if (viaIpc)
            Quickshell.execDetached(["qs", "ipc", "call", "cat", "react", event]);
        else
            Pet.react(event);
    }

    function runningText() {
        const parts = [];
        for (const t in Pet.running)
            parts.push(Pet.running[t].event + (t === "*" ? " (all)" : " (" + (Hyprland.toplevels.values.find(w => w.address === t)?.lastIpcObject?.class ?? "a window") + ")"));
        return parts.join(", ") || "–";
    }

    // auto -> on -> off -> auto
    function cycle(key) {
        const v = Pet.overrides[key];
        Pet.override(key, v === undefined ? true : v ? false : undefined);
    }

    function contextLabel(key, name) {
        const v = Pet.overrides[key];
        return name + ": " + (v === undefined ? "auto (" + (Pet.measured[key] ? "yes" : "no") + ")" : v ? "on" : "off");
    }

    anchors.bottom: true
    anchors.right: true
    margins.bottom: 24
    margins.right: 32
    implicitWidth: 430 // wide enough that no row wraps differently as labels change
    implicitHeight: content.implicitHeight + 2 * pad
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-cat-tester"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    FileView {
        path: Quickshell.env("HOME") + "/.config/cat/rig.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.expressions = Object.keys(JSON.parse(text()).expressions);
            } catch (e) {}
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Theme.surface_container
        border.color: Theme.outline_variant
        border.width: 1
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            SectionLabel {
                text: "Cat tester"
            }
            GlyphButton {
                glyph: 0xf0156 // close
                onClicked: Pet.testerOpen = false
            }
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            color: Theme.on_surface_variant
            font.family: Theme.uiFont
            font.pixelSize: 12
            text: "base " + Pet.base + "  ·  pinned " + (Pet.pinned || "–") + "  ·  reacting " + root.runningText() + "  ·  busy " + (Object.keys(Pet.busy).length || "–")
        }

        Heading {
            text: "Reactions"
            hint: "as the sources send them"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Object.keys(Pet.reactions)
                Pill {
                    required property string modelData
                    text: modelData
                    active: Object.values(Pet.running).some(r => r.event === modelData)
                    onClicked: root.react(modelData)
                }
            }
            Pill {
                text: "only " + (root.focused?.lastIpcObject?.class ?? "the focused window")
                glyph: root.onlyFocused ? 0xf0132 : 0xf0131
                active: root.onlyFocused
                onClicked: root.onlyFocused = !root.onlyFocused
            }
            Pill {
                text: "via qs ipc"
                glyph: root.viaIpc ? 0xf0132 : 0xf0131 // checked / unchecked box
                active: root.viaIpc
                onClicked: root.viaIpc = !root.viaIpc
            }
        }

        Heading {
            text: "Expressions"
            hint: "click to pin, again to unpin"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.expressions
                Pill {
                    required property string modelData
                    text: modelData
                    active: Pet.pinned === modelData
                    onClicked: Pet.pinned === modelData ? Pet.unpin() : Pet.pin(modelData)
                }
            }
        }

        Heading {
            text: "Motions"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Pill {
                text: "hop"
                onClicked: Pet.act("hop", 1)
            }
            Pill {
                text: "hop ×2"
                onClicked: Pet.act("hop", 2)
            }
            Pill {
                text: "jolt"
                onClicked: Pet.act("jolt", 1)
            }
            Pill {
                readonly property bool on: (Pet.busy[root.focused?.address ?? ""] ?? []).some(e => e.id === "tester")
                text: "busy: " + (root.focused?.lastIpcObject?.class ?? "focused window")
                glyph: on ? 0xf0132 : 0xf0131
                active: on
                onClicked: if (root.focused)
                    Pet.setBusy(root.focused.address, "tester", !on)
            }
            Pill {
                id: squishPill
                text: "hold to squish"
                active: squishMouse.pressed

                // Over the pill's own MouseArea: this one needs press and release, not clicks.
                MouseArea {
                    id: squishMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: Pet.squish(true)
                    onReleased: Pet.squish(false)
                    onCanceled: Pet.squish(false)
                }
            }
        }

        Heading {
            text: "Context"
            hint: "auto → on → off"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [["idle", "idle 5 min"], ["playing", "music"], ["night", "night"]]
                Pill {
                    required property var modelData
                    text: root.contextLabel(modelData[0], modelData[1])
                    active: Pet.overrides[modelData[0]] !== undefined
                    onClicked: root.cycle(modelData[0])
                }
            }
        }
    }

    component Heading: SectionLabel {
        Layout.topMargin: 6
    }
}
