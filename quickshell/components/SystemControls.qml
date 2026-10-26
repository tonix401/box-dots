import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower
import qs

// Power profile, the monitor's backlight and color temperature (Monitor.qml) and system stats. The stats
// are only read while `active`.
ColumnLayout {
    id: root

    property bool active: true

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Toggle {
            Layout.preferredWidth: 1
            glyph: PowerProfiles.profile === PowerProfile.PowerSaver ? 0xf032a : PowerProfiles.profile === PowerProfile.Performance ? 0xf14de : 0xf05d1
            label: PowerProfile.toString(PowerProfiles.profile)
            active: PowerProfiles.profile !== PowerProfile.Balanced
            onClicked: {
                // saver -> balanced -> performance -> saver
                const p = PowerProfiles.profile;
                PowerProfiles.profile = p === PowerProfile.PowerSaver ? PowerProfile.Balanced : p === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            columns: 2
            rowSpacing: 4
            columnSpacing: 4

            Stat {
                glyph: 0xf0ee0
                value: stats.cpu + "%"
            }
            Stat {
                glyph: 0xf035b
                value: stats.mem.toFixed(1) + "G"
            }
            Stat {
                glyph: 0xf050f
                value: stats.temp + "°"
            }
            Stat {
                glyph: 0xf02ca
                value: stats.disk
            }
        }
    }

    // backlight over DDC/CI, with software dimming at the bottom of the range
    SliderRow {
        glyph: Monitor.dim > 0 ? 0xf00de : Monitor.backlight < 0.5 ? 0xf00df : 0xf00e0
        value: Monitor.level
        label: Monitor.label
        visible: Monitor.bus !== ""
        onMoved: v => Monitor.setLevel(v)
        Component.onCompleted: Monitor.refresh()
    }

    // color temperature via the monitor's RGB gains
    SliderRow {
        readonly property int range: Monitor.maxTemperature - Monitor.minTemperature
        glyph: 0xf050f
        value: (Monitor.temperature - Monitor.minTemperature) / range
        label: Monitor.temperature + "K"
        visible: Monitor.available
        onMoved: v => Monitor.setTemperature(Monitor.minTemperature + v * range)
    }

    QtObject {
        id: stats

        property int cpu: 0
        property real mem: 0
        property int temp: 0
        property string disk: ""
        property var last: null
    }

    FileView {
        id: procStat
        path: "/proc/stat"
        blockLoading: true
    }
    FileView {
        id: procMem
        path: "/proc/meminfo"
        blockLoading: true
    }

    // coretemp's hwmon index changes between boots, so look it up
    Process {
        id: tempProc
        command: ["sh", "-c", "for h in /sys/class/hwmon/*; do [ \"$(cat $h/name)\" = coretemp ] && cat $h/temp1_input && break; done"]
        stdout: StdioCollector {
            onStreamFinished: stats.temp = Math.round(Number(text.trim()) / 1000)
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -h --output=used,size / | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [used, size] = text.trim().split(/\s+/);
                stats.disk = `${used}/${size}`;
            }
        }
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procStat.reload();
            const f = procStat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const cur = {
                idle: f[3] + f[4],
                total: f.reduce((a, b) => a + b, 0)
            };
            if (stats.last && cur.total > stats.last.total)
                stats.cpu = Math.round(100 * (1 - (cur.idle - stats.last.idle) / (cur.total - stats.last.total)));
            stats.last = cur;

            procMem.reload();
            const kb = k => Number(procMem.text().match(new RegExp("^" + k + ":\\s+(\\d+)", "m"))[1]);
            stats.mem = (kb("MemTotal") - kb("MemAvailable")) / (1024 * 1024);

            tempProc.running = true;
            diskProc.running = true;
        }
    }

    component Stat: Rectangle {
        property int glyph
        property string value

        Layout.fillWidth: true
        Layout.preferredHeight: 27
        radius: 8
        color: Theme.surface_container_high

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: Theme.g(parent.parent.glyph)
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
            Text {
                text: parent.parent.value
                color: Theme.on_surface
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }
}
