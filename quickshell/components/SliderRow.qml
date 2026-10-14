import QtQuick
import QtQuick.Layouts
import qs

// icon + draggable track + percentage (volume, brightness). Past 1, a tick marks 100%. An optional
// live `level` (audio peak) pulses inside the filled part.
RowLayout {
    id: slider

    property int glyph
    property real value // 0..maximum
    property real maximum: 1
    readonly property real fraction: Math.max(0, Math.min(1, value / maximum))
    property string label: Math.round(value * 100) + "%"
    property real level: -1 // live signal level 0..1 drawn inside the volume part; -1 = none
    signal moved(real value)
    signal iconClicked

    Layout.fillWidth: true
    spacing: 10

    Text {
        Layout.preferredWidth: 24
        text: Theme.g(slider.glyph)
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: 22

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.iconClicked()
        }
    }

    Rectangle {
        id: sliderTrack

        Layout.fillWidth: true
        Layout.preferredHeight: slider.level >= 0 ? 10 : 8
        radius: height / 2
        color: Theme.surface_container_highest

        // With a live `level`, the volume part is dimmed and the level pulses inside it.
        Rectangle {
            width: Math.max(height, parent.width * slider.fraction)
            height: parent.height
            radius: parent.radius
            color: slider.level >= 0 ? Qt.alpha(Theme.primary, 0.35) : Theme.primary

            Rectangle {
                visible: slider.level >= 0
                width: parent.width * Math.min(1, slider.level)
                height: parent.height
                radius: parent.radius
                color: Theme.primary
            }
        }

        // 100% mark when the track goes further
        Rectangle {
            visible: slider.maximum > 1
            x: Math.round(parent.width / slider.maximum) - 1
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 14
            radius: 1
            color: Theme.outline
        }

        Rectangle {
            x: parent.width * slider.fraction - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: Theme.primary
            border.width: 3
            border.color: Theme.surface
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            function set(x) {
                slider.moved(slider.maximum * Math.max(0, Math.min(1, (x - 8) / sliderTrack.width)));
            }
            onPressed: event => set(event.x)
            onPositionChanged: event => set(event.x)
        }
    }

    Text {
        Layout.preferredWidth: 72
        visible: slider.label !== ""
        horizontalAlignment: Text.AlignRight
        text: slider.label
        color: Theme.on_surface
        font.family: Theme.uiFont
        font.pixelSize: 15
    }
}
