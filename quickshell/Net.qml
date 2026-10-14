pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Network state for the bar's network block and the sidebar: link info from scripts/network.sh,
// live rates and their recent history. Polls every second while the sidebar shows the details.
Singleton {
    id: root

    property var info: ({})
    property real down: 0
    property real up: 0
    property var last: null
    // Recent rates for the sidebar's graph, oldest first.
    property var downHistory: []
    property var upHistory: []
    readonly property int historyLength: 60

    function toggleWifi() {
        net.act(Util.wifiPowerCommand(info.state === "disabled"));
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

    Poll {
        id: net
        command: [Quickshell.shellDir + "/scripts/network.sh"]
        interval: Sidebar.open ? 1000 : 5000
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
            root.last = Object.assign({
                time: now
            }, next);
            root.info = next;
        }
    }
}
