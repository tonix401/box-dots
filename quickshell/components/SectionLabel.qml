import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    property alias text: label.text
    property string hint: ""

    Layout.fillWidth: true

    Text {
        id: label
        color: Theme.primary
        font.family: Theme.uiFont
        font.pixelSize: 15
        font.weight: Font.Medium
    }
    Item {
        Layout.fillWidth: true
    }
    Text {
        text: parent.hint
        color: Theme.outline
        font.family: Theme.uiFont
        font.pixelSize: 12
    }
}
