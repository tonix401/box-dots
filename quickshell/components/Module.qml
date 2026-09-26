import QtQuick
import qs

// One clickable text label inside a segment, like a single waybar module.
Item {
    id: root

    property alias text: label.text
    property alias textFormat: label.textFormat
    property color fg
    property string tooltip: ""
    property int tooltipFormat: Text.PlainText
    readonly property bool hovered: mouse.containsMouse

    property real accX: 0
    property real accY: 0

    signal clicked
    signal rightClicked
    // One emission per wheel notch (120 units); dx/dy are -1, 0 or 1, positive = up/right.
    signal scrolled(int dx, int dy)

    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    BarText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        color: root.fg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: event => {
            root.accX += event.angleDelta.x;
            root.accY += event.angleDelta.y;
            while (Math.abs(root.accY) >= 120) {
                const s = Math.sign(root.accY);
                root.accY -= 120 * s;
                root.scrolled(0, s);
            }
            while (Math.abs(root.accX) >= 120) {
                const s = Math.sign(root.accX);
                root.accX -= 120 * s;
                root.scrolled(-s, 0);
            }
        }
    }

    Tooltip {
        target: root
        text: root.tooltip
        textFormat: root.tooltipFormat
        show: root.hovered
    }
}
