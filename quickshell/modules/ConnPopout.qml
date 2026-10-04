import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs
import qs.components

// Below the bluetooth / network / tailscale block: quick toggles, link details,
// a throughput graph and the paired bluetooth devices.
Popout {
    id: root

    required property Item network // modules/Network.qml

    alignRight: true
    contentWidth: 330

    readonly property var info: network.info
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter?.enabled ?? false
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.paired || d.connected).sort((a, b) => b.connected - a.connected || a.name.localeCompare(b.name))
    readonly property int btConnected: devices.filter(d => d.connected).length

    readonly property string linkDetails: {
        if (info.state !== "wifi")
            return info.state === "ethernet" ? `${info.ifname} · wired` : "";
        const band = info.freq >= 5925 ? "6 GHz" : info.freq >= 4900 ? "5 GHz" : "2.4 GHz";
        const parts = [`${info.signal}% signal`, band];
        if (info.bitrate > 0)
            parts.push(`${Math.round(info.bitrate / 1000)} Mbit/s`);
        if (info.security)
            parts.push(info.security);
        return parts.join(" · ");
    }

    // The header shows live traffic and the address; the states are on the toggles.
    header: Item {
        BarText {
            height: parent.height
            text: `${Theme.g(0xf019)} ${root.network.rate(root.network.down)}  ${Theme.g(0xf093)} ${root.network.rate(root.network.up)}`
            color: Theme.on_surface
        }
        BarText {
            anchors.right: parent.right
            height: parent.height
            text: Privacy.mask((root.info.ip ?? "").split("/")[0])
            color: Theme.on_surface
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Toggle {
                glyph: root.info.state === "ethernet" ? 0xef09 : root.info.state === "wifi" ? 0xf0928 : 0xf092e
                label: {
                    switch (root.info.state) {
                    case "wifi":
                        return Privacy.mask(root.info.ssid);
                    case "ethernet":
                        return "Ethernet";
                    case "disconnected":
                        return "Not connected";
                    default:
                        return "Wi-Fi off";
                    }
                }
                active: root.info.state === "wifi" || root.info.state === "ethernet"
                onClicked: root.network.toggleWifi()
            }
            Toggle {
                glyph: root.btConnected > 0 ? 0xf00b1 : root.btOn ? 0xf00af : 0xf00b2
                label: !root.btOn ? "Bluetooth off" : root.btConnected > 0 ? `${root.btConnected} connected` : "Bluetooth on"
                active: root.btOn
                onClicked: Util.run("rfkill toggle bluetooth")
            }
            Toggle {
                glyph: 0xeb53
                label: Tailscale.up ? "Tailnet up" : "Tailnet down"
                active: Tailscale.up
                onClicked: Tailscale.toggle()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.linkDetails
            elide: Text.ElideRight
            color: Theme.on_surface_variant
            font.family: Theme.uiFont
            font.pixelSize: 12
        }

        TrafficGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
        }

        SectionLabel {
            text: "Bluetooth"
            visible: root.devices.length > 0
        }

        Repeater {
            model: root.devices

            DeviceRow {
                required property BluetoothDevice modelData
                device: modelData
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextButton {
                text: "Wi-Fi settings"
                onClicked: Util.run("iwgtk")
            }
            TextButton {
                text: "Bluetooth settings"
                onClicked: Util.run("blueman-manager")
            }
        }
    }

    // Download filled, upload as a line, both on one scale; the peak is noted in the corner.
    component TrafficGraph: Item {
        id: graph

        readonly property var down: root.network.downHistory
        readonly property var up: root.network.upHistory
        readonly property real peak: Math.max(1, ...down, ...up)

        onDownChanged: canvas.requestPaint()
        onWidthChanged: canvas.requestPaint()

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.surface_container_high
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 6

            function path(ctx, values) {
                const n = root.network.historyLength;
                const step = width / (n - 1);
                const x0 = width - (values.length - 1) * step;
                ctx.beginPath();
                values.forEach((v, i) => {
                    const x = x0 + i * step, y = height - height * v / graph.peak;
                    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                });
                return x0;
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (graph.down.length < 2)
                    return;
                ctx.lineWidth = 1.5;
                ctx.lineJoin = "round";

                const x0 = path(ctx, graph.down);
                ctx.lineTo(width, height);
                ctx.lineTo(x0, height);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(Theme.primary, 0.3);
                ctx.fill();
                path(ctx, graph.down);
                ctx.strokeStyle = Theme.primary;
                ctx.stroke();

                path(ctx, graph.up);
                ctx.strokeStyle = Theme.tertiary;
                ctx.stroke();
            }
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            text: `peak ${root.network.rate(graph.peak)}`
            color: Theme.on_surface_variant
            font.family: Theme.uiFont
            font.pixelSize: 10
        }
    }

    component DeviceRow: Rectangle {
        id: row

        property BluetoothDevice device
        readonly property bool busy: device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting

        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 10
        color: rowMouse.containsMouse ? Theme.surface_container_high : "transparent"

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.btOn && !row.busy
            onClicked: row.device.connected = !row.device.connected
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 10

            Text {
                text: Theme.g(/audio|head/.test(row.device.icon) ? 0xf02cb : 0xf00af)
                color: row.device.connected ? Theme.primary : Theme.on_surface_variant
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }
            Text {
                Layout.fillWidth: true
                text: Privacy.mask(row.device.name)
                elide: Text.ElideRight
                color: Theme.on_surface
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: row.device.connected ? Font.Medium : Font.Normal
            }
            Text {
                visible: row.device.batteryAvailable && row.device.connected
                text: `${Math.round(row.device.battery * 100)}%`
                color: Theme.on_surface_variant
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
            Text {
                text: row.busy ? "…" : row.device.connected ? "Disconnect" : "Connect"
                color: Theme.primary
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
