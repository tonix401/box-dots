import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs

// The network tile (toggles Wi-Fi; its live traffic is drawn into the tile), Bluetooth and Tailscale
// toggles and the paired bluetooth devices. Network state comes from Net.
ColumnLayout {
    id: root

    readonly property var info: Net.info
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter?.enabled ?? false
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.paired || d.connected).sort((a, b) => b.connected - a.connected || a.name.localeCompare(b.name))
    readonly property int btConnected: devices.filter(d => d.connected).length

    spacing: 8

    NetworkTile {
        Layout.fillWidth: true
        Layout.preferredHeight: 66
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

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

    // Wi-Fi toggle as a wide tile: network name and link details on the left, live rates on the right,
    // and the last minute of traffic behind them (download filled, upload as a line, one scale).
    component NetworkTile: Rectangle {
        id: tile

        readonly property bool active: root.info.state === "wifi" || root.info.state === "ethernet"
        readonly property color fg: active ? Theme.on_primary : Theme.on_surface
        readonly property color graphColor: active ? Theme.on_primary : Theme.primary
        readonly property var down: Net.downHistory
        readonly property var up: Net.upHistory
        readonly property real peak: Math.max(1, ...down, ...up)

        readonly property string name: {
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
        readonly property string details: {
            const ip = Privacy.mask((root.info.ip ?? "").split("/")[0]);
            if (root.info.state === "ethernet")
                return [root.info.ifname, ip].filter(s => s).join(" · ");
            if (root.info.state !== "wifi")
                return "Click to turn Wi-Fi on";
            const band = root.info.freq >= 5925 ? "6 GHz" : root.info.freq >= 4900 ? "5 GHz" : "2.4 GHz";
            const parts = [`${root.info.signal}%`, band];
            if (root.info.bitrate > 0)
                parts.push(`${Math.round(root.info.bitrate / 1000)} Mbit/s`);
            if (ip)
                parts.push(ip);
            return parts.join(" · ");
        }

        radius: 12
        clip: true
        color: active ? Theme.primary : tileMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        onDownChanged: graph.requestPaint()
        onWidthChanged: graph.requestPaint()
        onGraphColorChanged: graph.requestPaint()

        // The graph uses the lower part of the tile so the text above stays readable.
        Canvas {
            id: graph

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.75
            visible: tile.active

            function path(ctx, values) {
                const n = Net.historyLength;
                const step = width / (n - 1);
                const x0 = width - (values.length - 1) * step;
                ctx.beginPath();
                values.forEach((v, i) => {
                    const x = x0 + i * step, y = height - height * v / tile.peak;
                    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                });
                return x0;
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (tile.down.length < 2)
                    return;
                ctx.lineWidth = 1.5;
                ctx.lineJoin = "round";

                const x0 = path(ctx, tile.down);
                ctx.lineTo(width, height);
                ctx.lineTo(x0, height);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(tile.graphColor, 0.16);
                ctx.fill();
                path(ctx, tile.down);
                ctx.strokeStyle = Qt.alpha(tile.graphColor, 0.45);
                ctx.stroke();

                path(ctx, tile.up);
                ctx.setLineDash([3, 3]);
                ctx.strokeStyle = Qt.alpha(tile.graphColor, 0.45);
                ctx.stroke();
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Text {
                Layout.alignment: Qt.AlignTop
                text: Theme.g(root.info.state === "ethernet" ? 0xef09 : tile.active ? Util.bucket([0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928], root.info.signal) : 0xf092e)
                color: tile.active ? Theme.on_primary : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Text {
                    width: parent.width
                    text: tile.name
                    elide: Text.ElideRight
                    color: tile.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    text: tile.details
                    elide: Text.ElideRight
                    color: Qt.alpha(tile.fg, 0.75)
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }
            }
            Column {
                Layout.alignment: Qt.AlignTop
                visible: tile.active
                spacing: 2

                Rate {
                    glyph: 0xf019
                    value: Net.down
                    color: tile.fg
                }
                Rate {
                    glyph: 0xf093
                    value: Net.up
                    color: tile.fg
                }
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => event.button === Qt.RightButton ? Util.run("iwgtk") : Net.toggleWifi()
        }
    }

    // "2.2kB/s ↓", right-aligned in its column
    component Rate: Text {
        property int glyph
        property real value

        anchors.right: parent?.right
        text: `${Net.rate(value)} ${Theme.g(glyph)}`
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    component DeviceRow: Rectangle {
        id: row

        property BluetoothDevice device
        readonly property bool busy: device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting

        Layout.fillWidth: true
        Layout.preferredHeight: 34
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
            // battery as a small bar instead of a number
            Rectangle {
                visible: row.device.batteryAvailable && row.device.connected
                Layout.preferredWidth: 24
                Layout.preferredHeight: 10
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: Theme.on_surface_variant

                Rectangle {
                    x: 2
                    y: 2
                    width: (parent.width - 4) * row.device.battery
                    height: parent.height - 4
                    radius: 1
                    color: row.device.battery < 0.2 ? Theme.error : Theme.primary
                }
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
