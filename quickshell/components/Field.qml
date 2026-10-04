import QtQuick
import QtQuick.Layouts
import qs

// Text field for the desktop widgets' forms. Enter emits accepted, Escape emits cancelled.
Rectangle {
    id: field

    property alias text: textInput.text
    property alias input: textInput
    property string placeholder: ""
    property int glyph: 0
    signal accepted
    signal cancelled

    Layout.fillWidth: true
    implicitHeight: 30
    radius: 8
    color: Theme.surface_container_high
    border.width: 1
    border.color: textInput.activeFocus ? Theme.primary : "transparent"

    Text {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: field.glyph !== 0
        text: Theme.g(field.glyph)
        color: Theme.on_surface_variant
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
    TextInput {
        id: textInput

        anchors.fill: parent
        anchors.leftMargin: field.glyph !== 0 ? 28 : 10
        anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        activeFocusOnTab: true
        color: Theme.on_surface
        selectionColor: Theme.primary
        selectedTextColor: Theme.on_primary
        font.family: Theme.uiFont
        font.pixelSize: 12
        onAccepted: field.accepted()
        Keys.onEscapePressed: field.cancelled()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: textInput.text === ""
            text: field.placeholder
            elide: Text.ElideRight
            color: Theme.outline
            font: textInput.font
        }
    }
}
