import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

// A rofi -dmenu lookalike: bordered box centered in the usable area, input bar and a list.
// Geometry defaults follow the shared shape of the rofi/*.rasi themes.
PanelWindow {
    id: root

    // ── content ──
    property var items: []
    property var matchText: item => item.text // a string, or an array of fields (any may match each token)
    property string matching: "normal" // "normal" (all tokens are substrings) or "fuzzy" (subsequence)
    property Component rowContent // gets `parent.entry` and `parent.selected`
    signal accepted(var item)

    // ── theme (window / mainbox / inputbar / listview / element) ──
    property int boxWidth: 580
    property int boxHeight: 0 // 0 = fit to `lines`
    property real fontPt: 12
    property bool showInput: true
    property string placeholder: ""
    property int lines: 10
    property bool fixedHeight: true
    property int listSpacing: 2
    property int rowPadV: 12
    property int rowPadH: 16
    property int rowRadius: 8
    property int rowContentHeight: fm.height
    property bool highlightSelected: true
    property bool scrollbar: false
    property bool cycle: true
    property Component side // optional widget left of the list (power menu image)
    property int sideSpacing: 10

    readonly property int rowHeight: rowPadV * 2 + Math.ceil(Math.max(fm.height, rowContentHeight))
    readonly property int inputHeight: showInput ? 20 + Math.ceil(fm.height) : 0
    readonly property int listHeight: fixedHeight || boxHeight === 0 ? lines * rowHeight + (lines - 1) * listSpacing : boxHeight - 4 - 20 - (showInput ? inputHeight + 8 : 0)
    readonly property int visibleRows: Math.max(1, Math.floor((listHeight + listSpacing) / (rowHeight + listSpacing)))

    property var filtered: items
    property int selected: 0

    // rofi splits the input into tokens; every token has to match (case-insensitively).
    function tokenMatches(text, token) {
        if (matching !== "fuzzy")
            return text.includes(token);
        let i = 0;
        for (const ch of token) {
            i = text.indexOf(ch, i);
            if (i < 0)
                return false;
            i += ch.length;
        }
        return true;
    }

    function matches(fields, query) {
        const texts = (Array.isArray(fields) ? fields : [fields]).map(f => String(f ?? "").toLowerCase());
        return query.toLowerCase().split(/\s+/).every(t => texts.some(text => tokenMatches(text, t)));
    }

    function refilter() {
        const q = input.text.trim();
        filtered = q === "" ? items : items.filter(it => matches(matchText(it), q));
        selected = 0;
    }

    function move(delta) {
        const n = filtered.length;
        if (n === 0)
            return;
        let next = selected + delta;
        if (cycle)
            next = ((next % n) + n) % n;
        selected = Math.max(0, Math.min(n - 1, next));
    }

    // Handlers run before closing: closing destroys the menu and everything they reference.
    function accept() {
        const item = filtered[selected];
        if (item !== undefined)
            accepted(item);
        Menus.close();
    }

    onItemsChanged: refilter()

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

    FontMetrics {
        id: fm
        font.family: Theme.fontFamily
        font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
        font.pointSize: root.fontPt
    }

    // click outside closes, like rofi's click-to-exit
    MouseArea {
        anchors.fill: parent
        onClicked: Menus.close()
    }

    Rectangle {
        id: box

        anchors.centerIn: parent
        width: root.boxWidth
        height: root.boxHeight > 0 ? root.boxHeight : 4 + 20 + (root.showInput ? root.inputHeight + 8 : 0) + (root.fixedHeight ? root.listHeight : list.contentHeight)
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // swallow clicks so they don't close the menu
        }

        Item {
            id: main
            anchors.fill: parent
            anchors.margins: 2 + 10

            TextInput {
                id: input

                x: 14
                width: parent.width - 28
                height: root.inputHeight
                visible: root.showInput
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                color: Theme.primary
                selectionColor: Theme.primary
                selectedTextColor: Theme.on_primary
                font.family: Theme.fontFamily
                font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
                font.pointSize: root.fontPt
                renderType: Text.NativeRendering
                onTextChanged: root.refilter()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: root.placeholder
                    color: Theme.on_surface_variant
                    font: input.font
                    renderType: Text.NativeRendering
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (event.key === Qt.Key_Escape || (ctrl && (event.key === Qt.Key_G || event.key === Qt.Key_BracketLeft)))
                        Menus.close();
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_M)))
                        root.accept();
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N))
                        root.move(1);
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P))
                        root.move(-1);
                    else if (event.key === Qt.Key_PageDown)
                        root.selected = Math.min(root.filtered.length - 1, root.selected + root.visibleRows);
                    else if (event.key === Qt.Key_PageUp)
                        root.selected = Math.max(0, root.selected - root.visibleRows);
                    else if (event.key === Qt.Key_Home && !root.showInput)
                        root.selected = 0;
                    else if (event.key === Qt.Key_End && !root.showInput)
                        root.selected = Math.max(0, root.filtered.length - 1);
                    else
                        return;
                    event.accepted = true;
                }
            }

            Row {
                y: root.showInput ? root.inputHeight + 8 : 0
                width: parent.width
                height: parent.height - y
                spacing: root.sideSpacing

                Loader {
                    id: sideLoader
                    active: root.side !== null
                    visible: active
                    width: active ? (parent.width - root.sideSpacing) / 2 : 0
                    height: parent.height
                    sourceComponent: root.side
                }

                Item {
                    width: parent.width - (sideLoader.active ? sideLoader.width + root.sideSpacing : 0)
                    height: parent.height

                    ListView {
                        id: list

                        // rofi's "continuous" scroll-method keeps the selection in the middle row.
                        readonly property int middle: Math.floor((root.visibleRows - (root.visibleRows % 2 === 0 ? 1 : 0)) / 2)
                        readonly property int offset: {
                            const n = root.filtered.length, rows = root.visibleRows, sel = root.selected;
                            if (sel <= middle)
                                return 0;
                            if (sel < n - (rows - middle))
                                return sel - middle;
                            return n > rows ? n - rows : 0;
                        }

                        width: parent.width - (root.scrollbar ? 4 + root.listSpacing : 0)
                        height: parent.height
                        clip: true
                        interactive: false
                        spacing: root.listSpacing
                        model: root.filtered
                        contentY: offset * (root.rowHeight + root.listSpacing)
                        cacheBuffer: 0
                        reuseItems: true

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property bool isSelected: index === root.selected

                            width: list.width
                            height: root.rowHeight
                            radius: root.rowRadius
                            color: isSelected && root.highlightSelected ? Theme.primary : "transparent"

                            Loader {
                                readonly property var entry: row.modelData
                                readonly property bool selected: row.isSelected && root.highlightSelected
                                readonly property real fontPt: root.fontPt

                                x: root.rowPadH
                                width: parent.width - 2 * root.rowPadH
                                height: parent.height
                                sourceComponent: root.rowContent
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.selected = row.index
                                onDoubleClicked: {
                                    root.selected = row.index;
                                    root.accept();
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: event => root.move(event.angleDelta.y > 0 ? -1 : 1)
                        }
                    }

                    // rofi scrollbar.c: handle = h * rows / (n + rows), positioned by the selected index
                    Rectangle {
                        readonly property int n: root.filtered.length
                        readonly property real rest: list.height * n / (n + root.visibleRows)

                        visible: root.scrollbar
                        anchors.right: parent.right
                        width: 4
                        height: list.height - rest
                        y: n > 1 ? Math.floor(root.selected * rest / (n - 1)) : 0
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
