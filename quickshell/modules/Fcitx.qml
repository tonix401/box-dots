import QtQuick
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
            text: Ime.label
            color: root.fg
            font.pixelSize: 13 // 10pt
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? Ime.toEnglish() : Ime.cycle()
    }
}
