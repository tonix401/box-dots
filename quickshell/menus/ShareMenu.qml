import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// Screen-share picker (see Share.qml): live previews of the screens and windows the app may capture,
// or a region drawn with slurp. Same box as the wallpaper picker. Keys: Tab / 1-3 switch tabs,
// arrows pick, R toggles "remember", Enter shares, Esc cancels.
PanelWindow {
    id: root

    readonly property var tabs: [
        {
            label: "Screens",
            glyph: 0xf0379
        },
        {
            label: "Windows",
            glyph: 0xf05af
        },
        {
            label: "Region",
            glyph: 0xf0a6d
        }
    ]
    property int tab: 0
    property int selected: 0

    readonly property var screens: Quickshell.screens
    readonly property var windows: Share.windows
    readonly property int count: tab === 0 ? screens.length : tab === 1 ? windows.length : 1
    readonly property int columns: tab === 1 ? 3 : 1

    function toplevel(w) {
        return Hyprland.toplevels.values.find(t => ("0x" + t.address.replace(/^0x/, "")).toLowerCase() === w.address);
    }

    function icon(appClass) {
        const entry = DesktopEntries.heuristicLookup(appClass);
        return Quickshell.iconPath(entry?.icon ?? appClass, "application-x-executable");
    }

    function switchTab(t) {
        tab = (t + tabs.length) % tabs.length;
        selected = 0;
    }

    function share() {
        if (tab === 2)
            Share.drawRegion();
        else if (tab === 0 && screens[selected])
            Share.answer(`screen:${screens[selected].name}`);
        else if (tab === 1 && windows[selected])
            Share.answer(`window:${windows[selected].id}`);
        else
            return;
        Menus.close();
    }

    function cancel() {
        Share.answer("");
        Menus.close();
    }

    // Closed any other way (another menu opened, the shell reloaded): the waiting script must still hear back.
    Component.onDestruction: {
        if (!Share.drawingRegion)
            Share.answer("");
    }

    // ── window: covers the usable area, box centered, click outside cancels ──
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
        onClicked: root.cancel()
    }

    // One preview tile: a capture (or the app icon when there is none) over a caption.
    component Tile: Item {
        id: tile

        property int index
        property alias source: capture.captureSource
        property bool live: false
        property string iconSource: ""
        property int glyph: 0
        property string caption
        property string detail: ""
        default property alias overlay: previewBox.data
        readonly property bool isSelected: index === root.selected
        readonly property bool hovered: tileMouse.containsMouse

        ClippingRectangle {
            id: previewBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: captionRow.top
            anchors.bottomMargin: 8
            radius: 10
            color: tile.hovered && !tile.isSelected ? Theme.surface_container_highest : Theme.surface_container_high

            ScreencopyView {
                id: capture

                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                constraintSize: Qt.size(parent.width - 16, parent.height - 16)
                live: tile.live
                paintCursor: false
                visible: hasContent
            }

            // no capture (minimized, other workspace not yet rendered, …): the app icon instead
            IconImage {
                anchors.centerIn: parent
                visible: !capture.hasContent && tile.iconSource !== ""
                implicitSize: 56
                source: tile.iconSource
            }
        }

        RowLayout {
            id: captionRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            height: 22
            spacing: 8

            IconImage {
                visible: tile.iconSource !== ""
                implicitSize: 18
                source: tile.iconSource
            }
            Text {
                visible: tile.glyph !== 0
                text: Theme.g(tile.glyph)
                color: tile.isSelected ? Theme.primary : Theme.on_surface_variant
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
            Text {
                Layout.fillWidth: true
                text: tile.caption
                elide: Text.ElideRight
                color: tile.isSelected ? Theme.primary : Theme.on_surface
                font.family: Theme.uiFont
                font.pixelSize: 13
            }
            Text {
                visible: tile.detail !== ""
                text: tile.detail
                color: Theme.outline
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }

        // selection ring around the preview
        Rectangle {
            x: previewBox.x - 3
            y: previewBox.y - 3
            width: previewBox.width + 6
            height: previewBox.height + 6
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
            onClicked: root.selected = tile.index
            onDoubleClicked: {
                root.selected = tile.index;
                root.share();
            }
        }
    }

    Rectangle {
        id: box

        anchors.centerIn: parent
        scale: Theme.popoutScale // laid out at full size, smaller on small screens
        width: 900
        height: 18 + 44 + 16 + 40 + 16 + 430 + 16 + 36 + 18
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // keep clicks inside from closing the menu
        }

        // all keys land here: the box has no text input
        Item {
            focus: true
            Keys.onPressed: event => {
                const k = event.key, n = root.count;
                if (k === Qt.Key_Escape)
                    root.cancel();
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                    root.share();
                else if (k === Qt.Key_Tab)
                    root.switchTab(root.tab + 1);
                else if (k === Qt.Key_Backtab)
                    root.switchTab(root.tab - 1);
                else if (k >= Qt.Key_1 && k <= Qt.Key_3)
                    root.switchTab(k - Qt.Key_1);
                else if (k === Qt.Key_R)
                    Share.allowToken = !Share.allowToken;
                else if (k === Qt.Key_Right || k === Qt.Key_L)
                    root.selected = Math.min(n - 1, root.selected + 1);
                else if (k === Qt.Key_Left || k === Qt.Key_H)
                    root.selected = Math.max(0, root.selected - 1);
                else if (k === Qt.Key_Down || k === Qt.Key_J)
                    root.selected = Math.min(n - 1, root.selected + root.columns);
                else if (k === Qt.Key_Up || k === Qt.Key_K)
                    root.selected = Math.max(0, root.selected - root.columns);
                else
                    return;
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            // ── header ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 12
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: Theme.g(0xf1483) // monitor-share
                        color: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Share your screen"
                        color: Theme.on_surface
                        font.family: Theme.uiFont
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                    Text {
                        text: "An app wants to capture your screen. Choose what it can see."
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }
            }

            // ── tabs ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 12
                color: Theme.surface_container_high

                Row {
                    id: tabRow
                    anchors.fill: parent
                    anchors.margins: 4

                    Repeater {
                        model: root.tabs

                        Rectangle {
                            id: tabButton

                            required property var modelData
                            required property int index
                            readonly property bool active: index === root.tab
                            readonly property int number: index === 0 ? root.screens.length : index === 1 ? root.windows.length : 0

                            width: tabRow.width / root.tabs.length
                            height: tabRow.height
                            radius: 9
                            color: active ? Theme.primary : tabMouse.containsMouse ? Theme.surface_container_highest : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: Theme.g(tabButton.modelData.glyph)
                                    color: tabButton.active ? Theme.on_primary : Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                }
                                Text {
                                    text: tabButton.modelData.label
                                    color: tabButton.active ? Theme.on_primary : Theme.on_surface
                                    font.family: Theme.uiFont
                                    font.pixelSize: 14
                                }
                                Text {
                                    visible: tabButton.number > 0
                                    text: tabButton.number
                                    color: tabButton.active ? Theme.on_primary : Theme.outline
                                    opacity: 0.8
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchTab(tabButton.index)
                            }
                        }
                    }
                }
            }

            // ── content ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 430

                // screens: side by side, each as large as fits
                Row {
                    id: screenRow

                    readonly property real tileWidth: (parent.width - (root.screens.length - 1) * spacing) / Math.max(1, root.screens.length)

                    anchors.fill: parent
                    visible: root.tab === 0
                    spacing: 14

                    Repeater {
                        model: root.tab === 0 ? root.screens : []

                        Item {
                            id: screenCell

                            required property var modelData
                            required property int index

                            width: screenRow.tileWidth
                            height: screenRow.height

                            Tile {
                                anchors.fill: parent
                                index: screenCell.index
                                source: screenCell.modelData
                                live: true
                                glyph: 0xf0379
                                caption: screenCell.modelData.name
                                detail: `${screenCell.modelData.width}×${screenCell.modelData.height}`
                            }
                        }
                    }
                }

                // windows: a scrolling 3-column grid
                GridView {
                    id: windowGrid

                    anchors.fill: parent
                    visible: root.tab === 1
                    clip: true
                    cellWidth: width / 3
                    cellHeight: 214
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.tab === 1 ? root.windows : []
                    currentIndex: root.selected
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        width: windowGrid.cellWidth
                        height: windowGrid.cellHeight

                        Tile {
                            anchors.fill: parent
                            anchors.margins: 7
                            index: cell.index
                            source: root.toplevel(cell.modelData)?.wayland ?? null
                            live: index === root.selected
                            iconSource: root.icon(cell.modelData.appClass)
                            caption: cell.modelData.title || cell.modelData.appClass
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.windows.length === 0
                        text: "No windows to share"
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                    }
                }

                // region: the screen under a dimmed overlay with a sample selection; choosing it runs slurp
                Tile {
                    anchors.fill: parent
                    visible: root.tab === 2
                    index: 0
                    source: root.tab === 2 ? root.screen : null
                    live: true
                    glyph: 0xf0a6d
                    caption: "Draw a region on the screen"
                    detail: "Enter to start · Esc in slurp to come back"

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.alpha(Theme.surface, 0.55)
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.42
                        height: parent.height * 0.5
                        radius: 6
                        color: Qt.alpha(Theme.primary, 0.12)
                        border.width: 2
                        border.color: Theme.primary

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Theme.g(0xf0a6d)
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 34
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Select an area"
                                color: Theme.on_surface
                                font.family: Theme.uiFont
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }

            // ── footer ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 10

                // remember: the app gets a restore token and may skip this dialog next time
                Item {
                    Layout.preferredWidth: rememberRow.implicitWidth
                    Layout.fillHeight: true

                    Row {
                        id: rememberRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 22
                            radius: 11
                            color: Share.allowToken ? Theme.primary : Theme.surface_container_highest

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Share.allowToken ? parent.width - width - 3 : 3
                                width: 16
                                height: 16
                                radius: 8
                                color: Share.allowToken ? Theme.on_primary : Theme.outline

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "Remember this choice"
                                color: Theme.on_surface
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                            }
                            Text {
                                text: "the app may skip this dialog next time"
                                color: Theme.outline
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Share.allowToken = !Share.allowToken
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: cancelLabel.implicitWidth + 36
                    Layout.fillHeight: true
                    radius: 18
                    color: cancelMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.on_surface
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancel()
                    }
                }

                Rectangle {
                    readonly property bool ready: root.count > 0

                    Layout.preferredWidth: shareRow.implicitWidth + 40
                    Layout.fillHeight: true
                    radius: 18
                    opacity: ready ? 1 : 0.4
                    color: shareMouse.containsMouse && ready ? Qt.lighter(Theme.primary, 1.1) : Theme.primary

                    Row {
                        id: shareRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: Theme.g(root.tab === 2 ? 0xf0a6d : 0xf0118) // selection-drag / cast
                            color: Theme.on_primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                        }
                        Text {
                            text: root.tab === 2 ? "Select" : "Share"
                            color: Theme.on_primary
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: shareMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.share()
                    }
                }
            }
        }
    }
}
