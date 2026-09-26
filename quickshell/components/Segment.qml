import QtQuick
import QtQuick.Layouts
import qs

// A solid powerline block, like a waybar group with `padding: 3px 10px`.
Rectangle {
    id: root

    property color fg
    default property alias content: row.data

    implicitWidth: Math.ceil(row.implicitWidth) + 20
    implicitHeight: Theme.barHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}
