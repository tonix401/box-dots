import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// Every notification not yet dismissed, in a panel on the right under the bar, with do not disturb
// and clear all. Opened from the bell in the bar or `qs ipc call notifications toggle`; a click
// outside or Escape closes it.
PanelWindow {
    id: root

    readonly property real k: Theme.popoutScale
    readonly property int panelWidth: Math.round(400 * k)
    readonly property int pad: Math.round(14 * k)

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        onClicked: Notifs.centerOpen = false
    }

    Rectangle {
        id: panel

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: root.panelWidth
        height: Math.min(parent.height - 16, layout.implicitHeight + 2 * root.pad)
        radius: 16
        color: Theme.surface_container
        border.width: 1
        border.color: Theme.outline_variant

        focus: true
        Keys.onEscapePressed: Notifs.centerOpen = false

        MouseArea {
            anchors.fill: parent // swallow clicks so they don't close the panel
        }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: root.pad
            spacing: Math.round(10 * root.k)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.k)

                Text {
                    text: "Notifications"
                    color: Theme.primary
                    font.family: Theme.uiFont
                    font.pixelSize: Math.round(15 * root.k)
                    font.weight: Font.Medium
                }
                Text {
                    Layout.fillWidth: true
                    text: Notifs.list.length || ""
                    color: Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: Math.round(12 * root.k)
                }
                GlyphButton {
                    glyph: Notifs.dnd ? 0xf009b : 0xf009a
                    size: Math.round(30 * root.k)
                    fg: Notifs.dnd ? Theme.primary : Theme.on_surface
                    onClicked: Notifs.setDnd(!Notifs.dnd)
                }
                GlyphButton {
                    glyph: 0xf0e8e
                    size: Math.round(30 * root.k)
                    enabled: Notifs.list.length > 0
                    onClicked: Notifs.clearAll()
                }
            }

            Text {
                visible: Notifs.dnd
                text: "Do not disturb: only critical notifications pop up"
                color: Theme.on_surface_variant
                font.family: Theme.uiFont
                font.pixelSize: Math.round(11 * root.k)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outline_variant
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(16 * root.k)
                Layout.bottomMargin: Math.round(16 * root.k)
                visible: Notifs.list.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No notifications"
                color: Theme.on_surface_variant
                font.family: Theme.uiFont
                font.pixelSize: Math.round(12 * root.k)
            }

            ListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                visible: Notifs.list.length > 0
                clip: true
                spacing: Math.round(8 * root.k)
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: Notifs.list
                }

                delegate: NotificationCard {
                    required property var modelData

                    width: listView.width
                    notification: modelData
                }
            }
        }
    }
}
