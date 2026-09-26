import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// Wallpaper picker (SUPER+P): a 3×3 grid of the most used wallpapers; typing switches to a searchable list.
// Applying runs the same steps as hypr/scripts/rofi/wallpaper-menu.py (awww, current-wallpaper files, matugen).
PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string sourceDir: home + "/Pictures/Wallpapers"
    readonly property string outDir: home + "/.cache/box-dots/wallpapers"
    readonly property string thumbDir: home + "/.cache/box-dots/wallpaper-thumbnails"
    readonly property string helpers: home + "/.config/hypr/scripts/helpers"
    readonly property var extensions: [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]

    property var wallpapers: [] // {stem, path}
    property var usage: ({}) // stem -> times applied
    property string current: "" // stem of the wallpaper in use

    readonly property bool searching: search.text.trim() !== ""

    // Most applied first; the current one breaks ties, then list order.
    readonly property var favourites: wallpapers.slice().sort((a, b) => (usage[b.stem] ?? 0) - (usage[a.stem] ?? 0) || (b.stem === current) - (a.stem === current)).slice(0, 9)

    property var results: []
    property int selected: 0 // index into the grid or the result list

    function fuzzy(text, token) {
        let i = 0;
        for (const ch of token) {
            i = text.indexOf(ch, i);
            if (i < 0)
                return false;
            i += ch.length;
        }
        return true;
    }

    function refilter() {
        const tokens = search.text.trim().toLowerCase().split(/\s+/).filter(t => t);
        results = wallpapers.filter(w => tokens.every(t => fuzzy(w.stem.toLowerCase(), t)));
        selected = 0;
    }

    function apply(w) {
        // use the resized copy when prepare-wallpaper-files.py made one
        const cmd = `img="$1"; [ -e "$2" ] && img="$2"
            awww img --transition-type grow --transition-duration 1.8 "$img" &
            python3 "$3/update-current-wallpaper.py" "$img" &
            matugen image "$img" --prefer saturation &`;
        Quickshell.execDetached(["sh", "-c", cmd, "sh", w.path, `${outDir}/${w.stem}.png`, helpers]);
        const counts = Object.assign({}, usage);
        counts[w.stem] = (counts[w.stem] ?? 0) + 1;
        usageFile.setText(JSON.stringify(counts, null, 2) + "\n");
        Menus.close();
    }

    function preview(w) {
        return `file://${outDir}/${w.stem}.png`;
    }

    // ── window: covers the usable area, box centered, click outside closes ──
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
        // fixed size: search (48) + gap (14) + three rows of monitor-shaped tiles, plus 18 padding
        readonly property real tileWidth: (width - 36 - 2 * 12) / 3
        readonly property real tileHeight: Math.round(tileWidth * 1440 / 3440)

        anchors.centerIn: parent
        width: 760
        height: 18 + 48 + 14 + 3 * tileHeight + 2 * 12 + 18
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // keep clicks inside from closing the menu
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // ── search ──
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
                            text: "Search wallpapers..."
                            color: Theme.on_surface_variant
                            font: search.font
                        }

                        Keys.onPressed: event => {
                            const k = event.key;
                            const count = root.searching ? root.results.length : root.favourites.length;
                            if (k === Qt.Key_Escape) {
                                Menus.close();
                            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                const list = root.searching ? root.results : root.favourites;
                                if (list[root.selected])
                                    root.apply(list[root.selected]);
                            } else if (count === 0) {
                                return;
                            } else if (root.searching && (k === Qt.Key_Down || k === Qt.Key_Tab)) {
                                root.selected = (root.selected + 1) % count;
                            } else if (root.searching && (k === Qt.Key_Up || k === Qt.Key_Backtab)) {
                                root.selected = (root.selected - 1 + count) % count;
                            } else if (!root.searching && (k === Qt.Key_Right || k === Qt.Key_Tab)) {
                                root.selected = (root.selected + 1) % count;
                            } else if (!root.searching && (k === Qt.Key_Left || k === Qt.Key_Backtab)) {
                                root.selected = (root.selected - 1 + count) % count;
                            } else if (!root.searching && k === Qt.Key_Down) {
                                root.selected = Math.min(count - 1, root.selected + 3);
                            } else if (!root.searching && k === Qt.Key_Up) {
                                root.selected = Math.max(0, root.selected - 3);
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }
            }

            // ── 3×3 of the most used ──
            GridLayout {
                id: grid

                readonly property real tileWidth: parent.parent.tileWidth
                readonly property real tileHeight: parent.parent.tileHeight

                Layout.fillWidth: true
                visible: !root.searching
                columns: 3
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: root.favourites

                    Item {
                        id: tile

                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === root.selected

                        Layout.preferredWidth: grid.tileWidth
                        Layout.preferredHeight: grid.tileHeight // monitor aspect

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Theme.surface_container_high

                            Image {
                                anchors.fill: parent
                                source: root.preview(tile.modelData)
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 480
                                asynchronous: true
                            }

                            // name on hover / selection
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 28
                                visible: tile.isSelected || tileMouse.containsMouse
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: Qt.alpha(Theme.surface, 0.9)
                                    }
                                }

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: Text.AlignBottom
                                    bottomPadding: 5
                                    text: tile.modelData.stem.replace(/\s*\(.*\)$/, "") // drop the "(tags)"
                                    elide: Text.ElideRight
                                    color: Theme.on_surface
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                        }

                        // current-wallpaper badge
                        Rectangle {
                            visible: tile.modelData.stem === root.current
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            width: 22
                            height: 22
                            radius: 11
                            color: Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: Theme.g(0xf012c) // check
                                color: Theme.on_primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }
                        }

                        // selection ring
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 13
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.primary
                            visible: tile.isSelected
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = tile.index
                            onClicked: root.apply(tile.modelData)
                        }
                    }
                }
            }

            // ── search results ──
            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.searching
                clip: true
                spacing: 2
                model: root.results
                currentIndex: root.selected
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.selected

                    width: list.width
                    height: 40
                    radius: 8
                    color: current ? Theme.primary : rowMouse.containsMouse ? Theme.surface_container_high : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 12
                        spacing: 12

                        ClippingRectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            color: Theme.surface_container_high

                            Image {
                                anchors.fill: parent
                                source: `file://${root.thumbDir}/${row.modelData.stem}.png`
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 56
                                asynchronous: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.stem
                            elide: Text.ElideRight
                            color: row.current ? Theme.on_primary : Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selected = row.index
                        onClicked: root.apply(row.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: "No wallpapers found"
                    color: Theme.on_surface_variant
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }
            }
        }
    }

    // ── data ──
    // Same as the rofi script: refresh the resized copies and thumbnails first, then list.
    Process {
        running: true
        command: ["sh", "-c", `python3 "$1/prepare-wallpaper-files.py" >/dev/null 2>&1; ls -1 "$2"`, "sh", root.helpers, root.sourceDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(n => root.extensions.some(ext => n.toLowerCase().endsWith(ext)));
                root.wallpapers = names.sort().map(name => ({
                            stem: name.replace(/\.[^.]*$/, ""),
                            path: `${root.sourceDir}/${name}`
                        }));
            }
        }
    }

    FileView {
        path: root.home + "/.cache/box-dots/current/wallpaper"
        onLoaded: root.current = text().trim().replace(/^.*\//, "").replace(/\.[^.]*$/, "")
    }

    FileView {
        id: usageFile
        path: Quickshell.statePath("wallpaper-usage.json")
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text());
            } catch (e) {}
        }
    }
}
