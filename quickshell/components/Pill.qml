import QtQuick
import qs

// Small rounded button; `active` fills it with the primary color, `dot` shows a color swatch.
Rectangle {
    id: pill

    property string text
    property int glyph: 0
    property bool active: false
    property color dot: "transparent"
    signal clicked

    implicitWidth: pillRow.implicitWidth + 24
    implicitHeight: 28
    radius: height / 2
    color: active ? (pillMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary) : pillMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

    Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.dot.a > 0
            width: 8
            height: 8
            radius: 4
            color: pill.dot
        }
        Text {
            visible: pill.glyph !== 0
            text: Theme.g(pill.glyph)
            color: pill.active ? Theme.on_primary : Theme.on_surface_variant
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
        Text {
            visible: pill.text !== ""
            text: pill.text
            color: pill.active ? Theme.on_primary : Theme.on_surface
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: pillMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
