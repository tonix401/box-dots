import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs

// One notification in the sidebar's history: icon, "App · 14:02", summary, body and action buttons.
// Clicking runs the default action, middle click or the × (shown on hover) dismisses it.
Rectangle {
    id: root

    required property Notification notification

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    readonly property string iconSource: Notifs.iconFor(notification)

    implicitHeight: Math.ceil(content.implicitHeight) + 20
    radius: 12
    color: hover.hovered ? Theme.surface_container_highest : Theme.surface_container_high

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: event => event.button === Qt.MiddleButton ? root.notification.dismiss() : Notifs.activate(root.notification)
    }

    // critical ones get an accent along the left edge
    Rectangle {
        visible: root.critical
        x: 0
        y: 10
        width: 3
        height: parent.height - 20
        radius: 1.5
        color: Theme.error
    }

    RowLayout {
        id: content

        x: 12
        y: 10
        width: parent.width - 24
        spacing: 10

        IconImage {
            Layout.alignment: Qt.AlignTop
            implicitSize: 32
            source: root.iconSource
            visible: root.iconSource !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: `${root.notification.appName || "Notification"} · ${Qt.formatTime(Notifs.shownAt[root.notification.id] ?? new Date(), "HH:mm")}`
                    elide: Text.ElideRight
                    color: root.critical ? Theme.error : Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }
                GlyphButton {
                    glyph: 0xf0156
                    size: 18
                    fg: Theme.on_surface_variant
                    visible: hover.hovered
                    onClicked: root.notification.dismiss()
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notification.summary
                visible: text !== ""
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.on_surface
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: root.notification.body
                visible: text !== ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                color: Theme.on_surface_variant
                linkColor: Theme.primary
                font.family: Theme.uiFont
                font.pixelSize: 12
                lineHeight: 1.15
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            NotificationActions {
                Layout.fillWidth: true
                Layout.topMargin: 4
                notification: root.notification
                buttons: root.buttons
            }
        }
    }
}
