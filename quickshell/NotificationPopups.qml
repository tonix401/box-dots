import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// New notifications, stacked top right under the bar on the focused screen. Hovering them stops
// their timeouts; they stay listed in the center after they go.
PanelWindow {
    id: root

    readonly property int cardWidth: Math.round(380 * Theme.popoutScale)

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors {
        top: true
        right: true
    }
    margins {
        top: 8
        right: 8
    }
    implicitWidth: cardWidth
    implicitHeight: Math.max(1, column.implicitHeight)
    visible: Notifs.popups.length > 0 && !Notifs.centerOpen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Only the cards take clicks.
    mask: Region {
        item: column
    }

    HoverHandler {
        onHoveredChanged: Notifs.hovered = hovered
    }

    Column {
        id: column

        width: root.cardWidth
        spacing: 8

        Repeater {
            model: ScriptModel {
                values: Notifs.popups
            }

            NotificationCard {
                required property var modelData

                width: root.cardWidth
                notification: modelData
                popup: true
                border.width: 1
                border.color: critical ? Theme.error : Theme.outline_variant
            }
        }
    }
}
