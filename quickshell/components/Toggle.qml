import QtQuick
import QtQuick.Layouts
import qs

// Quick-settings tile: glyph over a label, filled with the primary color while active.
Rectangle {
    id: toggle

    property int glyph
    property string label
    property bool active
    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: 58
    radius: 12
    color: active ? Theme.primary : toggleMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        Text {
            text: Theme.g(toggle.glyph)
            color: toggle.active ? Theme.on_primary : Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }
        Text {
            width: parent.width
            text: toggle.label
            elide: Text.ElideRight
            color: toggle.active ? Theme.on_primary : Theme.on_surface
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    MouseArea {
        id: toggleMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.clicked()
    }
}
