import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs
import qs.components

// Below the speaker / microphone block: volume sliders with live level meters and
// pickers for the default output and input. Both go up to 150%.
Popout {
    id: root

    alignRight: true
    contentWidth: 330

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource)

    function label(node) {
        return node.description || node.nickname || node.name;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    ColumnLayout {
        width: parent.width
        spacing: 8

        SectionLabel {
            text: "Output"
        }
        Channel {
            node: root.sink
            glyph: root.sink?.audio?.muted ? 0xeee8 : 0xf028
            maximum: 1.5
        }
        Repeater {
            model: root.sinks

            Choice {
                required property PwNode modelData
                node: modelData
                selected: modelData === root.sink
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        SectionLabel {
            Layout.topMargin: 6
            text: "Input"
        }
        Channel {
            node: root.source
            glyph: root.source?.audio?.muted ? 0xf131 : 0xf130
            maximum: 1.5
        }
        Repeater {
            model: root.sources

            Choice {
                required property PwNode modelData
                node: modelData
                selected: modelData === root.source
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        TextButton {
            Layout.topMargin: 6
            text: "Open mixer"
            onClicked: Util.run("pavucontrol")
        }
    }

    // Volume slider (icon toggles mute) with the node's live level underneath.
    component Channel: ColumnLayout {
        id: channel

        property PwNode node
        property int glyph
        property real maximum: 1

        Layout.fillWidth: true
        spacing: 4

        PwNodePeakMonitor {
            id: peak
            node: channel.node
            enabled: root.open
        }

        SliderRow {
            glyph: channel.glyph
            value: channel.node?.audio?.volume ?? 0
            maximum: channel.maximum
            opacity: channel.node?.audio?.muted ? 0.5 : 1
            onMoved: v => {
                if (channel.node?.audio)
                    channel.node.audio.volume = v;
            }
            onIconClicked: {
                if (channel.node?.audio)
                    channel.node.audio.muted = !channel.node.audio.muted;
            }
        }

        // lines up with the slider track: past the 24px icon and the row spacing
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 82
            Layout.preferredHeight: 3
            radius: 1.5
            color: Theme.surface_container_high

            Rectangle {
                width: Math.round(parent.width * Math.min(1, peak.peak))
                height: parent.height
                radius: 1.5
                color: Theme.tertiary
            }
        }
    }

    component Choice: Rectangle {
        id: choice

        property PwNode node
        property bool selected
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 10
        color: choiceMouse.containsMouse ? Theme.surface_container_high : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                radius: 8
                color: "transparent"
                border.width: 2
                border.color: choice.selected ? Theme.primary : Theme.outline

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.primary
                    visible: choice.selected
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.label(choice.node)
                elide: Text.ElideRight
                color: Theme.on_surface
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: choice.selected ? Font.Medium : Font.Normal
            }
        }

        MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.clicked()
        }
    }
}
