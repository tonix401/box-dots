import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs

// A notification's action buttons as a row of pills (the default action is the card click instead).
RowLayout {
    id: root

    required property Notification notification
    required property var buttons // NotificationAction, without "default"

    visible: buttons.length > 0
    spacing: 6

    Repeater {
        model: root.buttons

        Rectangle {
            id: button

            required property NotificationAction modelData

            Layout.fillWidth: true
            Layout.preferredHeight: 26
            radius: height / 2
            color: buttonMouse.containsMouse ? Theme.primary : Qt.alpha(Theme.primary, 0.15)

            Text {
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                text: button.modelData.text
                elide: Text.ElideRight
                color: buttonMouse.containsMouse ? Theme.on_primary : Theme.primary
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: buttonMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    button.modelData.invoke();
                    if (!root.notification.resident)
                        root.notification.dismiss();
                }
            }
        }
    }
}
