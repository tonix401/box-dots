import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Start menu (SUPER+SPACE): search on top — typing switches to app results — with pinned / most used
// apps, recent files, media, quick toggles, volume and system stats below, and user + power at the bottom.
PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string waybarScripts: home + "/.config/waybar/scripts"
    readonly property bool searching: search.text.trim() !== ""

    // ── search ──
    property var results: []
    property int selected: 0

    function refilter() {
        const q = search.text.trim();
        results = q === "" ? [] : Search.rank(Apps.sorted, q, e => [e.name, e.genericName, e.keywords.join(" "), e.categories.join(" "), e.execString], {
            fuzzy: true
        });
        selected = 0;
    }

    // Act first, close after: closing destroys this window and everything its handlers reference.
    function launch(entry) {
        Apps.launch(entry);
        Menus.close();
    }

    // ── helpers ──
    function ago(date) {
        const s = (Date.now() - date.getTime()) / 1000;
        if (s < 3600)
            return `${Math.max(1, Math.floor(s / 60))}m ago`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h ago`;
        return `${Math.floor(s / 86400)}d ago`;
    }

    function mimeIcon(mime) {
        return Quickshell.iconPath(mime.replace("/", "-"), true) || Quickshell.iconPath(mime.split("/")[0] + "-x-generic", true) || Quickshell.iconPath("text-x-generic", true);
    }

    // ── window: covers the usable area, box centered, click outside closes (like the rofi menus) ──
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        onClicked: Menus.close()
    }

    Rectangle {
        id: box

        anchors.centerIn: parent
        width: 880
        height: 670
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // keep clicks inside from closing the menu
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            // ── search field ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 12
                color: Theme.surface_container_high

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        text: Theme.g(0xf0349)
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                    }

                    TextInput {
                        id: search

                        Layout.fillWidth: true
                        focus: true
                        color: Theme.on_surface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        onTextChanged: root.refilter()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: "Search apps..."
                            color: Theme.on_surface_variant
                            font: search.font
                        }

                        Keys.onPressed: event => {
                            const n = root.results.length;
                            if (event.key === Qt.Key_Escape)
                                Menus.close();
                            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && n > 0)
                                root.launch(root.results[root.selected]);
                            else if ((event.key === Qt.Key_Down || event.key === Qt.Key_Tab) && n > 0)
                                root.selected = (root.selected + 1) % n;
                            else if ((event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) && n > 0)
                                root.selected = (root.selected - 1 + n) % n;
                            else
                                return;
                            event.accepted = true;
                        }
                    }
                }
            }

            // ── search results ──
            ListView {
                id: resultList

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.searching
                clip: true
                spacing: 2
                model: root.results
                currentIndex: root.selected
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: resultRow

                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.selected

                    width: resultList.width
                    height: 48
                    radius: 10
                    color: current ? Theme.primary : hoverArea.containsMouse ? Theme.surface_container_high : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 12

                        IconImage {
                            implicitSize: 26
                            source: Quickshell.iconPath(resultRow.modelData.icon, "application-x-executable")
                        }
                        Text {
                            text: resultRow.modelData.name
                            color: resultRow.current ? Theme.on_primary : Theme.on_surface
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                        }
                        Text {
                            Layout.fillWidth: true
                            text: resultRow.modelData.genericName || resultRow.modelData.comment || ""
                            elide: Text.ElideRight
                            color: resultRow.current ? Qt.alpha(Theme.on_primary, 0.7) : Theme.on_surface_variant
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => event.button === Qt.RightButton ? Apps.togglePin(resultRow.modelData) : root.launch(resultRow.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.searching && root.results.length === 0
                    text: "No apps found"
                    color: Theme.on_surface_variant
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                }
            }

            // ── home ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.searching
                spacing: 20

                // left: apps + recent files
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 6

                    SectionLabel {
                        text: Apps.pinnedEntries.length > 0 ? "Pinned" : "Most used"
                        hint: "right-click to " + (Apps.pinnedEntries.length > 0 ? "unpin" : "pin")
                    }

                    Grid {
                        columns: 6
                        spacing: 4

                        Repeater {
                            // pinned first, filled up with the most used apps
                            model: Apps.pinnedEntries.concat(Apps.mostUsed).slice(0, Math.max(12, Apps.pinnedEntries.length))

                            AppTile {
                                required property var modelData
                                entry: modelData
                            }
                        }
                    }

                    SectionLabel {
                        Layout.topMargin: 8
                        text: "Recent files"
                    }

                    Repeater {
                        model: recent.files

                        Rectangle {
                            id: fileRow

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            radius: 10
                            color: fileMouse.containsMouse ? Theme.surface_container_high : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 10
                                spacing: 10

                                IconImage {
                                    implicitSize: 22
                                    source: root.mimeIcon(fileRow.modelData.mime)
                                }
                                Column {
                                    Layout.fillWidth: true

                                    Text {
                                        width: parent.width
                                        text: fileRow.modelData.name
                                        elide: Text.ElideMiddle
                                        color: Theme.on_surface
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 15
                                    }
                                    Text {
                                        width: parent.width
                                        text: fileRow.modelData.dir
                                        elide: Text.ElideMiddle
                                        color: Theme.on_surface_variant
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }
                                }
                                Text {
                                    text: root.ago(fileRow.modelData.modified)
                                    color: Theme.outline
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }

                            MouseArea {
                                id: fileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // folders in the file manager (the system default opens kitty in the wrong place)
                                    const file = fileRow.modelData;
                                    Quickshell.execDetached(file.mime === "inode/directory" ? ["nemo", file.path] : ["xdg-open", file.path]);
                                    Menus.close();
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                // right: media, toggles, volume, stats
                ColumnLayout {
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    MediaCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        visible: player !== null
                        player: {
                            const players = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"));
                            return players.find(p => p.isPlaying) ?? players[0] ?? null;
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        Toggle {
                            glyph: active ? 0xf05a9 : 0xf05aa
                            label: active ? (Privacy.mask(net.info.ssid) || (net.info.state === "ethernet" ? "Ethernet" : "Wi-Fi")) : "Wi-Fi off"
                            active: net.info.state !== undefined && net.info.state !== "disabled"
                            onClicked: net.poll.act(`bash ${root.waybarScripts}/toggle_wifi.sh`)
                        }
                        Toggle {
                            readonly property var adapter: Bluetooth.defaultAdapter
                            readonly property var device: adapter?.devices.values.find(d => d.connected) ?? null
                            glyph: active ? 0xf00af : 0xf00b2
                            label: device ? Privacy.mask(device.name) : active ? "Bluetooth" : "Bluetooth off"
                            active: adapter?.enabled ?? false
                            onClicked: if (adapter)
                                adapter.enabled = !adapter.enabled
                        }
                        Toggle {
                            glyph: 0xeb53
                            label: "Tailscale " + (Tailscale.status || "…")
                            active: Tailscale.up
                            onClicked: Tailscale.toggle()
                        }
                        Toggle {
                            glyph: active ? 0xf009b : 0xf009a
                            label: active ? "Silenced" : "Notifications"
                            active: dnd.output === "true"
                            onClicked: dnd.act("swaync-client -d -sw")
                        }
                        Toggle {
                            glyph: PowerProfiles.profile === PowerProfile.PowerSaver ? 0xf032a : PowerProfiles.profile === PowerProfile.Performance ? 0xf14de : 0xf05d1
                            label: PowerProfile.toString(PowerProfiles.profile)
                            active: PowerProfiles.profile !== PowerProfile.Balanced
                            onClicked: {
                                // saver -> balanced -> performance -> saver
                                const p = PowerProfiles.profile;
                                PowerProfiles.profile = p === PowerProfile.PowerSaver ? PowerProfile.Balanced : p === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
                            }
                        }
                        Toggle {
                            readonly property var source: Pipewire.defaultAudioSource
                            glyph: active ? 0xf036c : 0xf036d
                            label: active ? "Mic on" : "Mic muted"
                            active: !(source?.audio?.muted ?? true)
                            onClicked: if (source?.audio)
                                source.audio.muted = !source.audio.muted
                        }
                    }

                    // volume
                    SliderRow {
                        readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
                        glyph: audio?.muted ? 0xf0581 : 0xf057e
                        value: Math.min(1, audio?.volume ?? 0)
                        onMoved: v => {
                            if (audio)
                                audio.volume = v;
                        }
                        onIconClicked: if (audio)
                            audio.muted = !audio.muted
                    }

                    PwObjectTracker {
                        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
                    }

                    // backlight over DDC/CI, with software dimming at the bottom of the range (Monitor.qml)
                    SliderRow {
                        glyph: Monitor.dim > 0 ? 0xf00de : Monitor.backlight < 0.5 ? 0xf00df : 0xf00e0
                        value: Monitor.level
                        label: Monitor.label
                        visible: Monitor.bus !== ""
                        onMoved: v => Monitor.setLevel(v)
                        Component.onCompleted: Monitor.refresh()
                    }

                    // color temperature via the monitor's RGB gains (Monitor.qml)
                    SliderRow {
                        readonly property int range: Monitor.maxTemperature - Monitor.minTemperature
                        glyph: 0xf050f
                        value: (Monitor.temperature - Monitor.minTemperature) / range
                        label: Monitor.temperature + "K"
                        visible: Monitor.available
                        onMoved: v => Monitor.setTemperature(Monitor.minTemperature + v * range)
                    }

                    // stats
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

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

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            // ── bottom: user + power ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.surface_container_highest
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ClippingRectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: Theme.surface_container_highest

                    Image {
                        anchors.fill: parent
                        source: "file://" + root.home + "/.cache/box-dots/current/wallpaper-square.png"
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                }

                Column {
                    Text {
                        text: Privacy.mask(whoami.output)
                        color: Theme.on_surface
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                    Text {
                        text: stats.uptime
                        color: Theme.on_surface_variant
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                PowerButton {
                    glyph: 0xf033e
                    tip: "Lock"
                    command: "hyprlock"
                    confirm: false
                }
                PowerButton {
                    glyph: 0xf0343
                    tip: "Log out"
                    command: "hyprshutdown -vt 2"
                }
                PowerButton {
                    glyph: 0xf0709
                    tip: "Reboot"
                    command: "systemctl reboot"
                }
                PowerButton {
                    glyph: 0xf0425
                    tip: "Shut down"
                    command: "systemctl poweroff"
                }
            }
        }
    }

    // ── data ──
    Poll {
        id: whoami
        command: ["sh", "-c", "echo \"$USER@$(cat /etc/hostname)\""]
    }

    QtObject {
        id: net
        property var info: ({})
        property Poll poll: Poll {
            command: [Quickshell.shellDir + "/scripts/network.sh"]
            onOutputChanged: {
                try {
                    net.info = JSON.parse(output);
                } catch (e) {}
            }
        }
    }

    Poll {
        id: dnd
        command: ["swaync-client", "-D"]
    }

    // GTK's recently-used list, newest first
    FileView {
        id: recent

        property var files: []

        path: root.home + "/.local/share/recently-used.xbel"
        onLoaded: {
            const out = [];
            const re = /<bookmark\s([^>]*)>([\s\S]*?)<\/bookmark>/g;
            let m;
            while ((m = re.exec(text())) !== null) {
                const href = (m[1].match(/href="([^"]+)"/) ?? [])[1];
                const modified = (m[1].match(/modified="([^"]+)"/) ?? [])[1];
                if (!href?.startsWith("file://"))
                    continue;
                const path = decodeURIComponent(href.slice(7));
                const slash = path.lastIndexOf("/");
                out.push({
                    href: href,
                    path: path,
                    name: path.slice(slash + 1),
                    dir: path.slice(0, slash).replace(root.home, "~") || "/",
                    mime: (m[2].match(/mime-type type="([^"]+)"/) ?? [])[1] ?? "text/plain",
                    modified: new Date(modified)
                });
            }
            // The list keeps entries for moved/deleted files; check the newest ones still exist.
            candidates = out.sort((a, b) => b.modified - a.modified).slice(0, 30);
            existCheck.command = ["sh", "-c", 'for p; do [ -e "$p" ] && echo "$p"; done', "sh"].concat(candidates.map(f => f.path));
            existCheck.running = true;
        }

        property var candidates: []

        property Process existCheck: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const existing = text.split("\n");
                    recent.files = recent.candidates.filter(f => existing.includes(f.path)).slice(0, 5);
                }
            }
        }
    }

    QtObject {
        id: stats

        property int cpu: 0
        property real mem: 0
        property int temp: 0
        property string disk: ""
        property string uptime: ""
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
    FileView {
        id: procUptime
        path: "/proc/uptime"
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
        running: true
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
        running: true
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

            procUptime.reload();
            const up = Math.floor(Number(procUptime.text().split(" ")[0]));
            const d = Math.floor(up / 86400), h = Math.floor(up % 86400 / 3600), min = Math.floor(up % 3600 / 60);
            stats.uptime = "up " + (d > 0 ? `${d}d ` : "") + (h > 0 ? `${h}h ` : "") + `${min}m`;

            tempProc.running = true;
        }
    }

    // ── pieces ──
    component AppTile: Rectangle {
        id: tile

        property var entry

        width: 72
        height: 80
        radius: 12
        color: tileMouse.containsMouse ? Theme.surface_container_high : "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 6

            IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: 36
                source: Quickshell.iconPath(tile.entry.icon, "application-x-executable")

                // pin marker
                Rectangle {
                    visible: Apps.isPinned(tile.entry)
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -4
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: Theme.g(0xf0403)
                        color: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
            Text {
                width: 66
                horizontalAlignment: Text.AlignHCenter
                text: tile.entry.name
                elide: Text.ElideRight
                color: Theme.on_surface
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => event.button === Qt.RightButton ? Apps.togglePin(tile.entry) : root.launch(tile.entry)
        }
    }

    component Stat: Rectangle {
        property int glyph
        property string value

        // width follows the content so a long value (disk) gets more room than a short one (cpu)
        Layout.fillWidth: true
        Layout.preferredWidth: statRow.implicitWidth + 16
        Layout.preferredHeight: 34
        radius: 8
        color: Theme.surface_container_high

        Row {
            id: statRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: Theme.g(parent.parent.glyph)
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 15
            }
            Text {
                text: parent.parent.value
                color: Theme.on_surface
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }
    }

    // Log out / reboot / shut down need a second click within 3s.
    component PowerButton: Rectangle {
        id: power

        property int glyph
        property string tip
        property string command
        property bool confirm: true
        property bool armed: false

        implicitWidth: armed ? armedLabel.implicitWidth + 24 : 36
        implicitHeight: 36
        radius: 18
        color: armed ? Theme.error_container : powerMouse.containsMouse ? Theme.surface_container_highest : "transparent"

        Behavior on implicitWidth {
            NumberAnimation {
                duration: 150
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !power.armed
            text: Theme.g(power.glyph)
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 20
        }
        Text {
            id: armedLabel
            anchors.centerIn: parent
            visible: power.armed
            text: power.tip + "?"
            color: Theme.on_surface
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        Timer {
            id: disarm
            interval: 3000
            onTriggered: power.armed = false
        }

        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (power.confirm && !power.armed) {
                    power.armed = true;
                    disarm.restart();
                    return;
                }
                Util.run(power.command);
                Menus.close();
            }
        }
    }
}
