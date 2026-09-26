import QtQuick
import Quickshell.Io
import qs
import qs.components

Module {
    id: root

    property real usedGb: 0

    text: Theme.g(0xf035b) + " " + usedGb.toFixed(1) + "GB"
    onClicked: Util.run("kitty -e btop")
    onRightClicked: Util.run("kitty -e btop")

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        blockLoading: true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            const kb = key => Number(meminfo.text().match(new RegExp("^" + key + ":\\s+(\\d+)", "m"))[1]);
            root.usedGb = (kb("MemTotal") - kb("MemAvailable")) / (1024 * 1024);
        }
    }
}
