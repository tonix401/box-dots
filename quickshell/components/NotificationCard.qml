import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs

// One notification, as a popup or in the center: app icon (or the sender's image), app name and
// time, summary, body and action buttons. Clicking it runs the default action.
Rectangle {
    id: root

    required property Notification notification
    property bool popup: false

    readonly property real k: Theme.popoutScale // smaller on small screens, like the bar's popouts
    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    readonly property string iconSource: {
        // Theme icons resolve to "" when the theme lacks them, so nothing is drawn instead of the
        // missing-image checkerboard.
        const themed = name => name.startsWith("/") ? "file://" + name : name.includes("/") ? name : Quickshell.iconPath(name, true);
        const n = notification;
        if (n.image)
            return n.image.startsWith("image://icon/") ? themed(n.image.slice(13)) : n.image;
        if (n.appIcon)
            return themed(n.appIcon);
        const entry = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        return entry ? themed(entry.icon) : "";
    }

    readonly property int pad: Math.round(12 * k)

    implicitHeight: Math.ceil(content.implicitHeight) + 2 * pad
    radius: Math.round(12 * k)
    color: critical ? Theme.error_container : mouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high
    border.width: critical ? 1 : 0
    border.color: Theme.error

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Middle click dismisses, like most notification daemons.
        onClicked: event => event.button === Qt.MiddleButton ? root.notification.dismiss() : Notifs.activate(root.notification)
    }

    RowLayout {
        id: content

        x: root.pad
        y: root.pad
        width: parent.width - 2 * root.pad
        spacing: Math.round(10 * root.k)

        IconImage {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Math.round(2 * root.k)
            implicitSize: Math.round(40 * root.k)
            source: root.iconSource
            visible: root.iconSource !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(2 * root.k)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.k)

                Text {
                    Layout.fillWidth: true
                    text: root.notification.appName.toUpperCase()
                    elide: Text.ElideRight
                    color: root.critical ? Theme.error : Theme.primary
                    font.family: Theme.uiFont
                    font.pixelSize: Math.round(10 * root.k)
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                }
                Text {
                    text: Qt.formatTime(Notifs.shownAt[root.notification.id] ?? new Date(), "HH:mm")
                    color: Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: Math.round(10 * root.k)
                }
                GlyphButton {
                    glyph: 0xf0156
                    size: Math.round(20 * root.k)
                    fg: Theme.on_surface_variant
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
                font.pixelSize: Math.round(14 * root.k)
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: root.notification.body
                visible: text !== ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 8
                elide: Text.ElideRight
                color: Theme.on_surface_variant
                linkColor: Theme.primary
                font.family: Theme.uiFont
                font.pixelSize: Math.round(12 * root.k)
                lineHeight: 1.2
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(6 * root.k)
                visible: root.buttons.length > 0
                spacing: Math.round(6 * root.k)

                Repeater {
                    model: root.buttons

                    Rectangle {
                        id: actionButton

                        required property NotificationAction modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(28 * root.k)
                        radius: height / 2
                        color: actionMouse.containsMouse ? Theme.primary : Qt.alpha(Theme.primary, 0.15)

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                            text: actionButton.modelData.text
                            elide: Text.ElideRight
                            color: actionMouse.containsMouse ? Theme.on_primary : Theme.primary
                            font.family: Theme.uiFont
                            font.pixelSize: Math.round(12 * root.k)
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionButton.modelData.invoke();
                                if (!root.notification.resident)
                                    root.notification.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
