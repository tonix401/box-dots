import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs

// A solid powerline block, like a waybar group with `padding: 3px 10px`.
Rectangle {
    id: root

    property color fg
    default property alias content: row.data

    implicitWidth: Util.snap(Math.ceil(row.implicitWidth) + 2 * Theme.segmentPad, Screen.devicePixelRatio)
    implicitHeight: Theme.barHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: Theme.segmentPad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}
