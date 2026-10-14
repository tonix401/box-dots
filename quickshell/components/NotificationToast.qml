import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs

// A new notification as a slim pill: icon, summary and app name. Hovering expands it in place to
// show the body and action buttons (and holds every toast's timeout, see NotificationPopups.qml).
// Click runs the default action, middle click dismisses.
Rectangle {
    id: root

    required property Notification notification

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    readonly property string iconSource: Notifs.iconFor(notification)
    // Without a summary the body is already on the pill.
    readonly property bool hasMore: (notification.summary !== "" && notification.body !== "") || buttons.length > 0
    readonly property bool expanded: hover.hovered && hasMore
    readonly property int rowHeight: 40

    implicitHeight: expanded ? rowHeight + more.implicitHeight + 10 : rowHeight
    radius: expanded ? 16 : rowHeight / 2
    clip: true
    color: Theme.surface_container
    border.width: 1
    border.color: critical ? Theme.error : Theme.outline_variant

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    Behavior on radius {
        NumberAnimation {
            duration: 160
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: event => event.button === Qt.MiddleButton ? root.notification.dismiss() : Notifs.activate(root.notification)
    }

    RowLayout {
        id: row

        x: 12
        width: parent.width - 28
        height: root.rowHeight
        spacing: 10

        IconImage {
            implicitSize: 20
            source: root.iconSource
            visible: root.iconSource !== ""
        }
        Text {
            visible: root.iconSource === ""
            text: Theme.g(root.critical ? 0xf0028 : 0xf009a)
            color: root.critical ? Theme.error : Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }
        Text {
            Layout.fillWidth: true
            text: root.notification.summary || root.notification.body
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.on_surface
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            Layout.maximumWidth: 110
            text: root.notification.appName
            elide: Text.ElideRight
            color: root.critical ? Theme.error : Theme.on_surface_variant
            font.family: Theme.uiFont
            font.pixelSize: 11
        }
    }

    ColumnLayout {
        id: more

        x: 14
        y: root.rowHeight - 6
        width: parent.width - 28
        spacing: 6
        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.notification.summary ? root.notification.body : ""
            visible: text !== ""
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 3
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
            notification: root.notification
            buttons: root.buttons
        }
    }
}
