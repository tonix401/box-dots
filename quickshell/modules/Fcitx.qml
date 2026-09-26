import QtQuick
import Quickshell
import qs
import qs.components

// "icon  <span size='10pt'>{}</span>" — the label is drawn smaller than the icon.
Item {
    id: root

    property color fg

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter

        BarText {
            anchors.baseline: name.baseline
            text: Theme.g(0xf05ca) + "  "
            color: root.fg
        }

        BarText {
            id: name
            anchors.verticalCenter: parent.verticalCenter
            text: im.output
            color: root.fg
            font.pixelSize: 13 // 10pt
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => im.act(event.button === Qt.RightButton ? "fcitx5-remote -s keyboard-us" : "~/.config/waybar/scripts/fcitx-cycle.sh")
    }

    Poll {
        id: im
        command: ["bash", Quickshell.env("HOME") + "/.config/waybar/scripts/fcitx.sh"]
        interval: 1000
    }
}
