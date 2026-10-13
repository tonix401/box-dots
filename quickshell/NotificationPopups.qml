import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// New notifications as toasts, stacked top right under the bar on the focused screen. Hovering them
// stops their timeouts; they stay listed in the sidebar after they go, and step aside while it's open.
PanelWindow {
    id: root

    readonly property int toastWidth: 360

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors {
        top: true
        right: true
    }
    margins {
        top: 8
        right: 8
    }
    implicitWidth: toastWidth
    // A fixed height: resizing the surface while a toast grows on hover makes Hyprland send a pointer
    // leave, which collapsed it again. The mask keeps the empty part click-through.
    implicitHeight: 800
    visible: Notifs.popups.length > 0 && !Sidebar.open
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Only the toasts take clicks.
    mask: Region {
        item: column
    }

    HoverHandler {
        onHoveredChanged: Notifs.hovered = hovered
    }

    Column {
        id: column

        width: root.toastWidth
        spacing: 6

        Repeater {
            model: ScriptModel {
                values: Notifs.popups
            }

            NotificationToast {
                required property var modelData

                width: root.toastWidth
                notification: modelData
            }
        }
    }
}
