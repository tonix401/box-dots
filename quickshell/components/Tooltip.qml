import QtQuick
import Quickshell
import qs

// Hover tooltip shown centered below `target`.
PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool show: false
    property int textFormat: Text.PlainText

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 8

    visible: show && text !== ""
    color: "transparent"
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 14

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.surface_container
        border.width: 1
        border.color: Theme.outline_variant

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            textFormat: root.textFormat
            color: Theme.on_surface
            font.family: Theme.uiFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }
    }
}
