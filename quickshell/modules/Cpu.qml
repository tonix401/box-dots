import QtQuick
import Quickshell.Io
import qs
import qs.components

Module {
    id: root

    property real lastTotal: 0
    property real lastIdle: 0
    property int usage: 0

    text: Theme.g(0xf0ee0) + " " + usage + "%"
    onClicked: Util.run("kitty -e btop")
    onRightClicked: Util.run("kitty -e btop")

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            const dt = total - root.lastTotal;
            if (root.lastTotal > 0 && dt > 0)
                root.usage = Math.round(100 * (1 - (idle - root.lastIdle) / dt));
            root.lastTotal = total;
            root.lastIdle = idle;
        }
    }
}
