import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

// Volume sliders for the default output and input with their live level pulsing inside the track
// (only measured while `active`), each over its current device; clicking that lists the others to
// switch to. Both go up to 150%.
ColumnLayout {
    id: root

    property bool active: true

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource)

    function label(node) {
        return node.description || node.nickname || node.name;
    }

    spacing: 6

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Channel {
        node: root.sink
        choices: root.sinks
        output: true
        glyph: root.sink?.audio?.muted ? 0xeee8 : 0xf028
        maximum: 1.5
        onPicked: n => Pipewire.preferredDefaultAudioSink = n
    }

    Channel {
        Layout.topMargin: 6
        node: root.source
        choices: root.sources
        glyph: root.source?.audio?.muted ? 0xf131 : 0xf130
        maximum: 1.5
        onPicked: n => Pipewire.preferredDefaultAudioSource = n
    }

    TextButton {
        Layout.topMargin: 4
        text: "Open mixer"
        onClicked: Util.run("pavucontrol")
    }

    // Volume slider (icon toggles mute) with the node's live level inside it and its device underneath.
    component Channel: ColumnLayout {
        id: channel

        property PwNode node
        property var choices: []
        property int glyph
        property real maximum: 1
        property bool picking: false
        signal picked(PwNode node)

        Connections {
            target: root
            function onActiveChanged() {
                if (!root.active)
                    channel.picking = false;
            }
        }

        Layout.fillWidth: true
        spacing: 4

        // The meter, VU-style: PipeWire reports a peak ~100 times a second; each frame shows the
        // newest one that is already audible (an output plays it `latencyMs` later, ~145 ms over
        // Bluetooth), jumping up at once and falling back smoothly.
        property bool output: false
        property int latencyMs: 0
        property real level: 0
        property var samples: [] // [ms, peak], oldest first; changed in place

        PwNodePeakMonitor {
            id: meter
            node: channel.node
            enabled: root.active
            onPeakChanged: channel.samples.push([Date.now(), meter.peak])
        }

        FrameAnimation {
            running: root.active
            onRunningChanged: if (!running) {
                channel.samples.length = 0;
                channel.level = 0;
            }
            onTriggered: {
                const now = Date.now() - channel.latencyMs, s = channel.samples;
                while (s.length > 1 && s[1][0] <= now)
                    s.shift();
                const peak = s.length > 0 && s[0][0] <= now ? s[0][1] : 0;
                channel.level = Math.max(peak, channel.level - frameTime * 1.6);
            }
        }

        // The device's own latency from PipeWire (pw-dump: the node's Latency param, "Input" side).
        function queryLatency() {
            latencyMs = 0;
            if (!output || !node)
                return;
            latency.command = ["pw-dump", String(node.id)];
            latency.running = true;
        }
        onNodeChanged: queryLatency()
        Component.onCompleted: queryLatency()

        Process {
            id: latency
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        // pw-dump lists related objects too; pick the node itself
                        const obj = JSON.parse(text).find(o => o.id === channel.node?.id);
                        const params = obj?.info?.params?.Latency ?? [];
                        const input = params.find(l => l.direction === "Input");
                        channel.latencyMs = Math.round((input?.maxNs ?? 0) / 1e6);
                    } catch (e) {}
                }
            }
        }

        SliderRow {
            glyph: channel.glyph
            value: channel.node?.audio?.volume ?? 0
            maximum: channel.maximum
            opacity: channel.node?.audio?.muted ? 0.5 : 1
            level: root.active ? channel.level : -1
            onMoved: v => {
                if (channel.node?.audio)
                    channel.node.audio.volume = v;
            }
            onIconClicked: {
                if (channel.node?.audio)
                    channel.node.audio.muted = !channel.node.audio.muted;
            }
        }

        // the current device; a click lists all of them
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 10
            color: deviceMouse.containsMouse ? Theme.surface_container_high : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 34
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: channel.node ? root.label(channel.node) : "No device"
                    elide: Text.ElideRight
                    color: Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
                Text {
                    visible: channel.choices.length > 1
                    text: Theme.g(channel.picking ? 0xf0143 : 0xf0140)
                    color: Theme.on_surface_variant
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            MouseArea {
                id: deviceMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: channel.choices.length > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: channel.picking = !channel.picking
            }
        }

        Repeater {
            model: channel.picking ? channel.choices : []

            Choice {
                required property PwNode modelData
                node: modelData
                selected: modelData === channel.node
                onClicked: {
                    channel.picked(modelData);
                    channel.picking = false;
                }
            }
        }
    }

    component Choice: Rectangle {
        id: choice

        property PwNode node
        property bool selected
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 30
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
