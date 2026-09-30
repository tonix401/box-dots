import QtQuick
import Quickshell
import qs
import qs.components

Module {
    id: root

    property var info: ({})
    property real down: 0
    property real up: 0
    property var last: null
    property bool detailed: false // poll every second while the drawer shows the details
    // Recent rates for the drawer's graph, oldest first.
    property var downHistory: []
    property var upHistory: []
    readonly property int historyLength: 60

    readonly property var wifiIcons: [0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928]

    function toggleWifi() {
        net.act("bash ~/.config/waybar/scripts/toggle_wifi.sh");
    }

    function rate(bytes) {
        const units = ["B", "kB", "MB", "GB"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) {
            bytes /= 1000;
            i++;
        }
        return (i === 0 ? Math.round(bytes) : bytes.toFixed(1)) + units[i] + "/s";
    }

    text: {
        switch (info.state) {
        case "wifi":
            return Theme.g(Util.bucket(wifiIcons, info.signal)) + " " + Privacy.mask(info.ssid);
        case "ethernet":
            return Theme.g(0xef09);
        case "disabled":
            return Theme.g(0xf092e);
        case "disconnected":
            return Theme.g(0xf0923) + "  disconnected";
        default:
            return "";
        }
    }
    onClicked: toggleWifi()
    onRightClicked: Util.run("iwgtk")

    Poll {
        id: net
        command: [Quickshell.shellDir + "/scripts/network.sh"]
        interval: root.detailed ? 1000 : 5000
        onOutputChanged: {
            let next;
            try {
                next = JSON.parse(output);
            } catch (e) {
                return;
            }
            const now = Date.now();
            if (root.last && root.last.ifname === next.ifname) {
                const dt = (now - root.last.time) / 1000;
                root.down = Math.max(0, (next.rx - root.last.rx) / dt);
                root.up = Math.max(0, (next.tx - root.last.tx) / dt);
                root.downHistory = root.downHistory.concat([root.down]).slice(-root.historyLength);
                root.upHistory = root.upHistory.concat([root.up]).slice(-root.historyLength);
            }
            root.last = Object.assign({ time: now }, next);
            root.info = next;
        }
    }
}
