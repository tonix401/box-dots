import QtQuick
import qs

// Round icon button (nerd-font glyph) that lights up on hover.
Rectangle {
    id: button

    property int glyph
    property int size: 30
    property color fg: Theme.on_surface
    property bool active: true
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: mouse.containsMouse && enabled ? Qt.alpha(fg, 0.12) : "transparent"
    opacity: enabled ? (active ? 1 : 0.55) : 0.3

    Text {
        anchors.centerIn: parent
        text: Theme.g(button.glyph)
        color: button.fg
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(button.size * 0.56)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: button.clicked()
    }
}
