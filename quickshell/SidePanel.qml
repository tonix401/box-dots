import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs
import qs.components

// The right-hand drawer: calendar, media, connections, sound and the notification history, each on
// its own island.
// A 2px strip along the right screen edge opens it on hover (not over a fullscreen window); it
// slides back once the pointer leaves. Open / pinned state lives in Sidebar.qml.
Scope {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    readonly property int panelWidth: 400
    readonly property int pad: 10 // around the islands

    // playerctld only mirrors another player (same choice as the bar's media block)
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

    PanelWindow {
        id: edge

        screen: root.focusedScreen
        anchors {
            top: true
            bottom: true
            right: true
        }
        implicitWidth: 2
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Normal
        visible: !(Hyprland.focusedWorkspace?.hasFullscreen ?? false)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-sidebar-edge"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // A hidden surface gets no leave event.
        onVisibleChanged: if (!visible)
            Sidebar.edgeHovered = false

        HoverHandler {
            onHoveredChanged: Sidebar.edgeHovered = hovered
        }
    }

    PanelWindow {
        id: drawer

        screen: root.focusedScreen
        anchors {
            top: true
            bottom: true
            right: true
        }
        margins.top: 6 // under the bar's exclusive zone
        implicitWidth: root.panelWidth
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Normal
        visible: panel.shown > 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-sidebar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // While it slides, only the part already in view takes the pointer.
        mask: Region {
            item: panel
        }

        onVisibleChanged: if (!visible)
            Sidebar.panelHovered = false

        Rectangle {
            id: panel

            property real shown: Sidebar.open ? 1 : 0

            Behavior on shown {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Slides in from the right; its right side (rounding and border) stays past the screen edge.
            x: root.panelWidth * (1 - shown)
            width: root.panelWidth + radius
            height: parent.height
            radius: 16
            color: Theme.surface_container_low
            border.width: 1
            border.color: Theme.outline_variant

            HoverHandler {
                onHoveredChanged: Sidebar.panelHovered = hovered
            }

            Flickable {
                id: flick

                x: root.pad
                y: root.pad
                width: root.panelWidth - 2 * root.pad
                height: parent.height - 2 * root.pad
                contentHeight: Math.max(height, column.implicitHeight)
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: column

                    width: flick.width
                    height: flick.contentHeight
                    spacing: 10

                    Island {
                        CalendarView {
                            Layout.fillWidth: true
                            active: Sidebar.open
                        }
                    }

                    MediaCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        visible: player !== null
                        player: root.player
                    }

                    Island {
                        ConnControls {
                            Layout.fillWidth: true
                        }
                    }

                    Island {
                        AudioControls {
                            Layout.fillWidth: true
                            active: Sidebar.open
                        }
                    }

                    Island {
                        SystemControls {
                            Layout.fillWidth: true
                            active: Sidebar.open
                        }
                    }

                    // shell extras that cost CPU while shown (Settings.qml)
                    Island {
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Toggle {
                                glyph: 0xf011b // cat
                                label: Settings.kittyCats ? "Kitty cats on" : "Kitty cats off"
                                active: Settings.kittyCats
                                onClicked: Settings.set("kittyCats", !Settings.kittyCats)
                            }
                            Toggle {
                                glyph: 0xf0d78 // gif box
                                label: Settings.barGif ? "Bar GIF on" : "Bar GIF off"
                                active: Settings.barGif
                                onClicked: Settings.set("barGif", !Settings.barGif)
                            }
                        }
                    }

                    // notifications: takes the rest of the height, the list scrolls
                    Island {
                        Layout.fillHeight: true
                        fill: true

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Notifications"
                                color: Theme.primary
                                font.family: Theme.uiFont
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                text: Notifs.list.length || ""
                                color: Theme.on_surface_variant
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                            GlyphButton {
                                glyph: Notifs.dnd ? 0xf009b : 0xf009a
                                fg: Notifs.dnd ? Theme.primary : Theme.on_surface
                                onClicked: Notifs.setDnd(!Notifs.dnd)
                            }
                            GlyphButton {
                                glyph: 0xf00e2 // broom: clear all
                                enabled: Notifs.list.length > 0
                                onClicked: Notifs.clearAll()
                            }
                        }

                        Text {
                            visible: Notifs.dnd
                            text: "Do not disturb: only critical notifications pop up"
                            color: Theme.on_surface_variant
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            visible: Notifs.list.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            text: "No notifications"
                            color: Theme.on_surface_variant
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                        }

                        ListView {
                            id: list

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: Math.min(contentHeight, 220)
                            visible: Notifs.list.length > 0
                            clip: true
                            spacing: 8
                            boundsBehavior: Flickable.StopAtBounds
                            model: ScriptModel {
                                values: Notifs.list
                            }

                            delegate: NotificationCard {
                                required property var modelData

                                width: list.width
                                notification: modelData
                            }
                        }

                        // with nothing to list, the rest of the island stays empty below the header
                        Item {
                            Layout.fillHeight: true
                            visible: !list.visible
                        }
                    }
                }
            }
        }
    }

    // A rounded group of controls. With `fill` it takes the height it's given (for the list in it).
    component Island: Rectangle {
        id: island

        default property alias content: inner.data
        property bool fill: false
        readonly property int pad: 12

        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 2 * pad
        radius: 16
        color: Theme.surface_container

        ColumnLayout {
            id: inner

            x: island.pad
            y: island.pad
            width: island.width - 2 * island.pad
            height: island.fill ? island.height - 2 * island.pad : implicitHeight
            spacing: 10
        }
    }
}
