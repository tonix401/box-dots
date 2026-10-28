import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// Wallpaper picker (SUPER+P): a scrollable grid of every wallpaper (most recently applied first,
// optionally narrowed by a color-direction filter); typing switches to a searchable list.
// Applying sets it with awww, updates the current-wallpaper files and re-themes with matugen.
PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string sourceDir: home + "/Pictures/Wallpapers"
    readonly property string outDir: home + "/.cache/box-dots/wallpapers"
    readonly property string thumbDir: home + "/.cache/box-dots/wallpaper-thumbnails"
    readonly property string previewDir: home + "/.cache/box-dots/wallpaper-previews"
    readonly property string helpers: home + "/.config/hypr/scripts/helpers"
    readonly property var extensions: [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"]

    property var wallpapers: [] // {stem, path}
    property var recent: [] // stems, most recently applied first
    property string current: "" // stem of the wallpaper in use

    readonly property bool searching: search.text.trim() !== ""

    // Per-wallpaper {colors: [primary, secondary, tertiary], direction} from prepare-wallpaper-files.py,
    // which asks matugen what it *would* theme with. Used for the swatches and the direction filter chips.
    property var palettes: ({})

    function paletteFor(stem) {
        return root.palettes[stem] ?? null;
    }

    readonly property var directions: ["red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink", "neutral"]
    readonly property var directionSwatch: ({
            red: "#e0574c",
            orange: "#e08a3c",
            yellow: "#d6c440",
            green: "#5cb86b",
            cyan: "#45b8c4",
            blue: "#4c86d8",
            purple: "#9166d8",
            pink: "#d86ab0",
            neutral: "#9aa0a6"
        })
    property string activeDirection: "" // "" = no filter

    function setDirection(d) {
        activeDirection = activeDirection === d ? "" : d;
        refilter();
    }

    // Wallpapers left after the color-direction filter; search then ranks within this set.
    readonly property var filtered: activeDirection === "" ? wallpapers : wallpapers.filter(w => paletteFor(w.stem)?.direction === activeDirection)

    // All filtered wallpapers, current then most-recently-applied first, the rest in list order — the
    // browse grid scrolls through this whole set, so there's no cap here unlike a typical "top 9".
    readonly property var ordered: {
        const order = [current, ...recent];
        const rank = w => {
            const i = order.indexOf(w.stem);
            return i === -1 ? order.length : i;
        };
        return filtered.slice().sort((a, b) => rank(a) - rank(b));
    }

    property var results: []
    property int selected: 0 // index into the grid or the result list

    function refilter() {
        results = Search.rank(filtered, search.text, w => w.stem, {
            fuzzy: true
        });
        selected = 0;
    }

    function apply(w) {
        // use the resized copy when prepare-wallpaper-files.py made one; matugen reads the small preview ($6), which
        // is ~10x faster and gives the same palette on most wallpapers.
        // Each step's exit is logged to wallpaper-apply.log in ms since the click/Enter ($5), to chase slow transitions.
        const cmd = `img="$1"; [ -e "$2" ] && img="$2"; log="$4"; t0="$5"
            colors="$img"; [ -e "$6" ] && colors="$6"
            ts() { echo "+$(( $(date +%s%3N) - t0 ))ms $*" >> "$log"; }
            echo "--- $(date '+%F %T') $img" >> "$log"
            ts "sh started"
            { awww img --transition-type grow --transition-duration 1.8 "$img"; ts "awww img exited $?"; } &
            { python3 "$3/update-current-wallpaper.py" "$img"; ts "update-current-wallpaper exited $?"; } &
            { matugen image "$colors" --prefer saturation; ts "matugen exited $?"; } &
            wait
            tail -n 500 "$log" > "$log.tmp" && mv "$log.tmp" "$log"`;
        Quickshell.execDetached(["sh", "-c", cmd, "sh", w.path, `${outDir}/${w.stem}.png`, helpers, `${home}/.cache/box-dots/wallpaper-apply.log`, String(Date.now()), `${previewDir}/${w.stem}.png`]);
        recentFile.setText(JSON.stringify([w.stem, ...recent.filter(s => s !== w.stem)].slice(0, 30), null, 2) + "\n");
        Menus.close();
    }

    // small monitor-shaped copy from prepare-wallpaper-files.py; the full-size one takes ~60ms each to decode
    function preview(w) {
        return `file://${previewDir}/${w.stem}.png`;
    }

    function setWallpapers(text) {
        const names = text.split("\n").filter(n => extensions.some(ext => n.toLowerCase().endsWith(ext)));
        wallpapers = names.sort().map(name => ({
                    stem: name.replace(/\.[^.]*$/, ""),
                    path: `${sourceDir}/${name}`
                }));
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
        id: panel

        // fixed size: search (48) + gap (14) + filter chips (30) + gap (14) + three rows of monitor-shaped
        // tiles (each row's own height already includes its gap, GridView-style), plus 18 padding
        readonly property real cellGap: 12
        readonly property real tileWidth: (width - 36) / 3 - cellGap
        readonly property real tileHeight: Math.round(tileWidth * 1440 / 3440)
        readonly property real cellWidth: tileWidth + cellGap
        readonly property real cellHeight: tileHeight + cellGap

        anchors.centerIn: parent
        width: 760
        height: 18 + 48 + 14 + 30 + 14 + 3 * cellHeight + 18
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
                        font.family: Theme.uiFont
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
                            const count = root.searching ? root.results.length : root.ordered.length;
                            if (k === Qt.Key_Escape) {
                                Menus.close();
                            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                const list = root.searching ? root.results : root.ordered;
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

            // ── color-direction filter chips ──
            RowLayout {
                id: filterRow

                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                Repeater {
                    model: root.directions

                    Rectangle {
                        id: chip

                        required property string modelData
                        readonly property bool active: root.activeDirection === modelData

                        readonly property color swatch: root.directionSwatch[modelData]
                        readonly property bool hovered: chipMouse.containsMouse

                        // equal-width chips spanning the row; each is tinted with its own direction color
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 30
                        radius: 15
                        color: active ? Qt.alpha(swatch, 0.28) : hovered ? Qt.alpha(swatch, 0.14) : Theme.surface_container_high
                        border.width: active ? 1.5 : 0
                        border.color: swatch

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: chip.active ? 10 : 8
                                height: width
                                radius: width / 2
                                color: chip.swatch

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData
                                color: chip.active || chip.hovered ? Theme.on_surface : Theme.on_surface_variant
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                font.weight: chip.active ? Font.DemiBold : Font.Normal
                                font.capitalization: Font.Capitalize
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setDirection(chip.modelData)
                        }
                    }
                }
            }

            // ── scrollable grid of every filtered wallpaper, favourites first ──
            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.preferredHeight: 3 * panel.cellHeight // exactly 3 rows visible; the rest scrolls
                visible: !root.searching
                clip: true
                cellWidth: panel.cellWidth
                cellHeight: panel.cellHeight
                boundsBehavior: Flickable.StopAtBounds
                model: root.ordered
                currentIndex: root.selected
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool isSelected: index === root.selected

                    width: grid.cellWidth
                    height: grid.cellHeight

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: panel.cellGap / 2
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
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                        }
                    }

                    // palette swatches from the theme matugen would generate for this wallpaper
                    Row {
                        readonly property var colors: root.paletteFor(tile.modelData.stem)?.colors ?? []

                        visible: colors.length > 0
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: panel.cellGap / 2 + 6
                        spacing: 4

                        Repeater {
                            model: parent.colors

                            Rectangle {
                                width: 11
                                height: 11
                                radius: 5.5
                                color: modelData
                                border.width: 1
                                border.color: Qt.alpha("#000000", 0.4)
                            }
                        }
                    }

                    // current-wallpaper badge
                    Rectangle {
                        visible: tile.modelData.stem === root.current
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: panel.cellGap / 2 + 6
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
                        anchors.margins: panel.cellGap / 2 - 3
                        radius: 13
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.primary
                        visible: tile.isSelected
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        anchors.margins: panel.cellGap / 2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = tile.index
                        onClicked: root.apply(tile.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.ordered.length === 0
                    text: "No wallpapers found"
                    color: Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: 15
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
                            font.family: Theme.uiFont
                            font.pixelSize: 15
                        }

                        Row {
                            readonly property var colors: root.paletteFor(row.modelData.stem)?.colors ?? []

                            visible: colors.length > 0
                            spacing: 3

                            Repeater {
                                model: parent.colors

                                Rectangle {
                                    width: 9
                                    height: 9
                                    radius: 4.5
                                    color: modelData
                                    border.width: 1
                                    border.color: Qt.alpha("#000000", 0.4)
                                }
                            }
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
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                }
            }
        }
    }

    // ── data ──
    // List right away from the cached files, then refresh the resized copies, previews and thumbnails in the
    // background; only when that made something new (it prints a line per file) is the list loaded again.
    Process {
        running: true
        command: ["ls", "-1", root.sourceDir]
        stdout: StdioCollector {
            onStreamFinished: root.setWallpapers(text)
        }
    }

    Process {
        running: true
        command: ["sh", "-c", `out=$(python3 "$1/prepare-wallpaper-files.py" 2>/dev/null) && [ -n "$out" ] && ls -1 "$2"`, "sh", root.helpers, root.sourceDir]
        stdout: StdioCollector {
            onStreamFinished: if (text !== "")
                root.setWallpapers(text)
        }
    }

    FileView {
        path: root.home + "/.cache/box-dots/current/wallpaper"
        onLoaded: root.current = text().trim().replace(/^.*\//, "").replace(/\.[^.]*$/, "")
    }

    FileView {
        id: recentFile
        path: Quickshell.statePath("wallpaper-recent.json")
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text());
            } catch (e) {}
        }
    }

    FileView {
        path: root.home + "/.cache/box-dots/wallpaper-palettes.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palettes = JSON.parse(text());
            } catch (e) {}
        }
    }
}
