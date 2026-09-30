import QtQuick
import QtQuick.Layouts
import qs

// Pill-shaped text button filling its row.
Rectangle {
    id: button

    property alias text: label.text
    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: 32
    implicitWidth: label.implicitWidth + 32
    radius: 16
    color: buttonMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.on_surface
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
