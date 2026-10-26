import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components

// Start menu (SUPER+SPACE): one search over apps, recent files, folders (zoxide) and fish's command
// history, plus a calculator. A prefix narrows it: ">" commands (Enter runs the typed text), "/" files
// and folders, "=" calculator. Empty, it shows the most used apps, recent files and recent commands;
// user + power at the bottom.
PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property bool searching: search.text.trim() !== ""

    // ── sources: every item is { kind, title, sub, fields, ... }; `fields` is what the search matches ──
    readonly property var appItems: Apps.sorted.map(e => ({
                kind: "app",
                entry: e,
                title: e.name,
                sub: e.genericName || e.comment || "",
                fields: [e.name, e.genericName, e.keywords.join(" "), e.categories.join(" "), e.execString]
            }))
    property var fileItems: []
    property var dirItems: []
    property var cmdItems: []
    // Each mode's list is kept as one array, so Search's per-keystroke cache stays valid while typing.
    readonly property var allItems: appItems.concat(fileItems, dirItems, cmdItems)
    readonly property var placeItems: fileItems.concat(dirItems)

    readonly property var groups: [
        {
            kind: "calc",
            label: "Calculator"
        },
        {
            kind: "run",
            label: "Run"
        },
        {
            kind: "app",
            label: "Apps",
            cap: 6
        },
        {
            kind: "file",
            label: "Recent files",
            cap: 4
        },
        {
            kind: "dir",
            label: "Folders",
            cap: 4
        },
        {
            kind: "cmd",
            label: "Commands",
            cap: 5
        }
    ]

    // ── search ──
    property var rows: [] // items, and { header } rows between the groups
    property var picks: [] // indices of the selectable rows
    property int selected: 0 // index into picks
    readonly property var current: picks.length > 0 ? rows[picks[selected]] : null

    function fieldsOf(item) {
        return item.fields;
    }

    // Math's functions and constants by lowercase name (sqrt, sin, pi, e, ln2, ...), plus ln for log.
    readonly property var mathNames: {
        const names = {
            ln: "log"
        };
        for (const n of Object.getOwnPropertyNames(Math))
            names[n.toLowerCase()] = n;
        return names;
    }

    // JavaScript arithmetic with ^ for powers and Math's names. Only numbers, operators and those names get
    // through to the evaluator. "." is the decimal point; a comma only separates a function's arguments
    // (max(1, 2.5)). Anywhere else it's refused: JavaScript's comma operator would turn "1,5*2" into 10.
    function calc(expr) {
        if (!/^[\w\s+\-*/%^().,]+$/.test(expr) || !/[\d(]/.test(expr))
            return null;
        const calls = []; // per open parenthesis: is it a function call's?
        for (let i = 0; i < expr.length; i++) {
            const c = expr[i];
            if (c === "(")
                calls.push(/[a-z_][a-z0-9_]*\s*$/i.test(expr.slice(0, i)));
            else if (c === ")")
                calls.pop();
            else if (c === "," && !calls[calls.length - 1])
                return null;
        }
        let unknown = false;
        const js = expr.replace(/[a-z_][a-z0-9_]*/gi, w => {
            const k = w.toLowerCase();
            const n = Object.prototype.hasOwnProperty.call(mathNames, k) ? mathNames[k] : undefined; // not "constructor"
            unknown = unknown || n === undefined;
            return "Math." + n;
        });
        if (unknown)
            return null;
        try {
            const v = Function(`"use strict"; return (${js.replace(/\^/g, "**")});`)();
            return typeof v === "number" && isFinite(v) ? String(Number(v.toPrecision(12))) : null;
        } catch (e) {
            return null;
        }
    }

    function refilter() {
        const text = search.text.trim();
        const mode = text[0] === ">" || text[0] === "/" || text[0] === "=" ? text[0] : "";
        const q = (mode ? text.slice(1) : text).trim();
        const found = [];

        // without "=": only with an operator or a function call, so plain numbers and words stay searches
        if (mode === "=" || mode === "" && /[+\-*/%^]|[a-z]\s*\(/i.test(q)) {
            const v = calc(q);
            if (v !== null)
                found.push({
                    kind: "calc",
                    title: v,
                    sub: ""
                });
        }
        if (mode === ">" && q !== "")
            found.push({
                kind: "run",
                title: q,
                sub: ""
            });
        if (mode !== "=" && (q !== "" || mode !== "")) {
            const items = mode === ">" ? cmdItems : mode === "/" ? placeItems : allItems;
            found.push(...Search.rank(items, q, fieldsOf, {
                fuzzy: true
            }));
        }

        // group in a fixed order, each group in rank order; a prefix lifts the caps
        const out = [], sel = [];
        for (const g of groups) {
            const hits = found.filter(it => it.kind === g.kind).slice(0, mode ? 50 : g.cap ?? 1);
            if (hits.length === 0)
                continue;
            out.push({
                header: g.label
            });
            for (const it of hits) {
                sel.push(out.length);
                out.push(it);
            }
        }
        rows = out;
        picks = sel;
        selected = 0;
    }

    // Act first, close after: closing destroys this window and everything its handlers reference.
    function activate(item) {
        switch (item.kind) {
        case "app":
            Apps.launch(item.entry);
            break;
        case "file":
            // folders in the file manager (the system default opens kitty in the wrong place)
            Quickshell.execDetached(item.mime === "inode/directory" ? ["nemo", item.path] : ["xdg-open", item.path]);
            break;
        case "dir":
            Quickshell.execDetached(["nemo", item.path]);
            break;
        case "cmd":
        case "run":
            // fish -C: run it, then stay at the prompt
            Quickshell.execDetached(["uwsm", "app", "--", "kitty", "fish", "-C", item.title]);
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", item.title]);
            break;
        }
        Menus.close();
    }

    function iconOf(item) {
        switch (item.kind) {
        case "app":
            return Quickshell.iconPath(item.entry.icon, "application-x-executable");
        case "file":
            return mimeIcon(item.mime);
        case "dir":
            return Quickshell.iconPath("folder", true);
        }
        return "";
    }

    function glyphOf(item) {
        return item.kind === "calc" ? 0xf00ec : item.kind === "cmd" || item.kind === "run" ? 0xf489 : 0;
    }

    // ── app menu (right-click, or → / Menu on an app): the app's desktop actions ──
    property var ctxEntry: null
    property var ctxItems: [] // { name, icon, run }
    property int ctxSelected: -1
    property point ctxPos

    // `item` and (x, y) say where to put the menu; `keyboard` preselects the first item.
    function openCtx(entry, item, x, y, keyboard) {
        if (entry.actions.length === 0)
            return;
        ctxItems = entry.actions.map(a => ({
                    name: a.name,
                    icon: a.icon,
                    run: () => {
                        Apps.launchAction(entry, a);
                        Menus.close();
                    }
                }));
        ctxSelected = keyboard ? 0 : -1;
        ctxPos = item.mapToItem(ctxLayer, x, y);
        ctxEntry = entry;
    }

    function closeCtx() {
        ctxEntry = null;
        ctxItems = [];
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

    function tilde(path) {
        return path.startsWith(home) ? "~" + path.slice(home.length) : path;
    }

    // new data while searching: rank again
    onAllItemsChanged: if (searching)
        refilter()

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
        width: 640
        height: layout.implicitHeight + 2 * layout.anchors.margins // sized by the home view (see resultList)
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // keep clicks inside from closing the menu
        }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

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
                        font.family: Theme.uiFont
                        font.pixelSize: 17
                        onTextChanged: root.refilter()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: "Search apps, files, commands..."
                            color: Theme.on_surface_variant
                            font: search.font
                        }

                        Keys.onPressed: event => {
                            if (root.ctxEntry !== null) {
                                const m = root.ctxItems.length;
                                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left)
                                    root.closeCtx();
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (root.ctxSelected >= 0)
                                        root.ctxItems[root.ctxSelected].run();
                                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                                    root.ctxSelected = (root.ctxSelected + 1) % m;
                                else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                                    root.ctxSelected = root.ctxSelected <= 0 ? m - 1 : root.ctxSelected - 1;
                                else {
                                    root.closeCtx(); // typing goes on into the search
                                    return;
                                }
                                event.accepted = true;
                                return;
                            }
                            const n = root.picks.length;
                            if (event.key === Qt.Key_Escape)
                                Menus.close();
                            else if ((event.key === Qt.Key_Menu || event.key === Qt.Key_Right && cursorPosition === text.length) && root.current?.kind === "app") {
                                const row = resultList.itemAtIndex(root.picks[root.selected]);
                                if (!row)
                                    return;
                                root.openCtx(root.current.entry, row, 48, row.height - 4, true);
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && n > 0)
                                root.activate(root.current);
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
                // as tall as the home view, so the box keeps its size while typing
                Layout.preferredHeight: homeView.implicitHeight
                visible: root.searching
                clip: true
                spacing: 2
                model: root.rows
                currentIndex: root.picks[root.selected] ?? -1
                highlightMoveDuration: 0

                // a group's header or one of its items
                delegate: Item {
                    id: resultRow

                    required property var modelData
                    required property int index
                    readonly property bool isHeader: modelData.header !== undefined

                    width: resultList.width
                    height: isHeader ? header.implicitHeight + (index > 0 ? 10 : 0) : itemRow.implicitHeight

                    SectionLabel {
                        id: header
                        visible: resultRow.isHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: resultRow.modelData.header ?? ""
                    }
                    ResultRow {
                        id: itemRow
                        visible: !resultRow.isHeader
                        entryItem: resultRow.isHeader ? ({
                                kind: "",
                                title: "",
                                sub: ""
                            }) : resultRow.modelData
                        current: resultRow.index === root.picks[root.selected] // modelData is a copy, so not by identity
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.searching && root.rows.length === 0
                    text: "Nothing found"
                    color: Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: 16
                }
            }

            // ── home ──
            ColumnLayout {
                id: homeView

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.searching
                spacing: 6

                SectionLabel {
                    text: "Most used"
                }

                Grid {
                    columns: 7
                    spacing: 6

                    Repeater {
                        model: Apps.mostUsed.slice(0, 14)

                        AppTile {
                            required property var modelData
                            entry: modelData
                        }
                    }
                }

                SectionLabel {
                    Layout.topMargin: 8
                    text: "Recent files"
                    visible: root.fileItems.length > 0
                }

                Repeater {
                    model: root.fileItems.slice(0, 3)

                    ResultRow {
                        required property var modelData
                        Layout.fillWidth: true
                        entryItem: modelData
                    }
                }

                SectionLabel {
                    Layout.topMargin: 8
                    text: "Recent commands"
                    visible: root.cmdItems.length > 0
                }

                Repeater {
                    model: root.cmdItems.slice(0, 2)

                    ResultRow {
                        required property var modelData
                        Layout.fillWidth: true
                        entryItem: modelData
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                // the prefixes, clickable
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            {
                                prefix: ">",
                                label: "commands"
                            },
                            {
                                prefix: "/",
                                label: "files & folders"
                            },
                            {
                                prefix: "=",
                                label: "calculator"
                            }
                        ]

                        Rectangle {
                            id: chip

                            required property var modelData

                            implicitWidth: chipText.implicitWidth + 20
                            implicitHeight: 26
                            radius: 13
                            color: chipMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: `<b>${chip.modelData.prefix}</b>  ${chip.modelData.label}`
                                textFormat: Text.StyledText
                                color: Theme.on_surface_variant
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    search.text = chip.modelData.prefix;
                                    search.forceActiveFocus();
                                }
                            }
                        }
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
                        asynchronous: true
                        cache: false
                    }
                }

                Column {
                    Text {
                        text: Privacy.mask(whoami.output)
                        color: Theme.on_surface
                        font.family: Theme.uiFont
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                    Text {
                        text: {
                            const up = Math.floor(Number((procUptime.text() || "0").split(" ")[0]));
                            const d = Math.floor(up / 86400), h = Math.floor(up % 86400 / 3600), min = Math.floor(up % 3600 / 60);
                            return "up " + (d > 0 ? `${d}d ` : "") + (h > 0 ? `${h}h ` : "") + `${min}m`;
                        }
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
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

    // the app menu, over everything; a click anywhere else only closes it
    Item {
        id: ctxLayer

        anchors.fill: parent
        visible: root.ctxEntry !== null

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.closeCtx()
        }

        Rectangle {
            id: ctxMenu

            x: Math.max(8, Math.min(root.ctxPos.x, ctxLayer.width - width - 8))
            y: root.ctxPos.y + height + 8 > ctxLayer.height ? root.ctxPos.y - height : root.ctxPos.y
            width: 260
            height: ctxColumn.implicitHeight + 12
            radius: 12
            color: Theme.surface_container
            border.width: 1
            border.color: Theme.outline_variant

            MouseArea {
                anchors.fill: parent // keep clicks between the rows from closing the menu
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Column {
                id: ctxColumn

                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                // which app this is for
                RowLayout {
                    width: parent.width
                    height: 36
                    spacing: 10

                    IconImage {
                        Layout.leftMargin: 8
                        implicitSize: 20
                        asynchronous: true
                        source: root.ctxEntry ? Quickshell.iconPath(root.ctxEntry.icon, "application-x-executable") : ""
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.ctxEntry?.name ?? ""
                        elide: Text.ElideRight
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }

                Repeater {
                    model: root.ctxItems

                    Rectangle {
                        id: ctxRow

                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.ctxSelected

                        width: ctxColumn.width
                        height: 36
                        radius: 8
                        color: current ? Theme.primary : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 10
                            spacing: 10

                            IconImage {
                                implicitSize: 20
                                asynchronous: true
                                source: ctxRow.modelData.icon ? Quickshell.iconPath(ctxRow.modelData.icon, true) : ""
                            }
                            Text {
                                Layout.fillWidth: true
                                text: ctxRow.modelData.name
                                elide: Text.ElideRight
                                color: ctxRow.current ? Theme.on_primary : Theme.on_surface
                                font.family: Theme.uiFont
                                font.pixelSize: 15
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.ctxSelected = ctxRow.index
                            onClicked: ctxRow.modelData.run()
                        }
                    }
                }
            }
        }
    }

    // ── data, all loaded after the window is up ──
    Poll {
        id: whoami
        command: ["sh", "-c", "echo \"$USER@$(cat /etc/hostname)\""]
    }

    FileView {
        id: procUptime
        path: "/proc/uptime"
    }

    // GTK's recently-used list, newest first
    FileView {
        id: recent

        path: root.home + "/.local/share/recently-used.xbel"
        onLoaded: {
            const out = [];
            const re = /<bookmark\s([^>]*)>([\s\S]*?)<\/bookmark>/g;
            const xml = text();
            let m;
            while ((m = re.exec(xml)) !== null) {
                const href = (m[1].match(/href="([^"]+)"/) ?? [])[1];
                const modified = (m[1].match(/modified="([^"]+)"/) ?? [])[1];
                if (!href?.startsWith("file://"))
                    continue;
                const path = decodeURIComponent(href.slice(7));
                const slash = path.lastIndexOf("/");
                out.push({
                    kind: "file",
                    path: path,
                    title: path.slice(slash + 1),
                    sub: root.tilde(path.slice(0, slash)) || "/",
                    mime: (m[2].match(/mime-type type="([^"]+)"/) ?? [])[1] ?? "text/plain",
                    modified: new Date(modified)
                });
            }
            // The list keeps entries for moved/deleted files; check the newest ones still exist.
            candidates = out.sort((a, b) => b.modified - a.modified).slice(0, 40);
            for (const f of candidates)
                f.fields = [f.title, f.sub];
            existCheck.command = ["sh", "-c", 'for p; do [ -e "$p" ] && echo "$p"; done', "sh"].concat(candidates.map(f => f.path));
            existCheck.running = true;
        }

        property var candidates: []

        property Process existCheck: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const existing = new Set(text.split("\n"));
                    root.fileItems = recent.candidates.filter(f => existing.has(f.path));
                }
            }
        }
    }

    // zoxide's folders, most used first
    Process {
        running: true
        command: ["zoxide", "query", "--list"]
        stdout: StdioCollector {
            onStreamFinished: root.dirItems = text.split("\n").filter(p => p && p !== root.home).slice(0, 300).map(p => {
                const name = p.slice(p.lastIndexOf("/") + 1);
                const short = root.tilde(p);
                return {
                    kind: "dir",
                    path: p,
                    title: name,
                    sub: short,
                    fields: [name, short]
                };
            })
        }
    }

    // fish's history ("- cmd: …" entries, oldest first), newest first without repeats
    FileView {
        path: root.home + "/.local/share/fish/fish_history"
        onLoaded: {
            const seen = new Set(), out = [];
            const lines = text().split("\n");
            for (let i = lines.length - 1; i >= 0 && out.length < 2000; i--) {
                const line = lines[i];
                if (!line.startsWith("- cmd: "))
                    continue;
                const cmd = line.slice(7).replace(/\\(.)/g, (_, c) => c === "n" ? "\n" : c);
                if (seen.has(cmd))
                    continue;
                seen.add(cmd);
                out.push({
                    kind: "cmd",
                    title: cmd,
                    sub: "",
                    fields: [cmd]
                });
            }
            root.cmdItems = out;
        }
    }

    // ── pieces ──
    // one row: an app, file, folder, command or the calculator
    component ResultRow: Rectangle {
        id: row

        property var entryItem
        property bool current: false
        readonly property int glyph: root.glyphOf(entryItem)

        width: parent?.width ?? 0
        implicitHeight: entryItem.kind === "file" ? 46 : 42
        height: implicitHeight
        radius: 10
        color: current ? Theme.primary : rowMouse.containsMouse ? Theme.surface_container_high : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 12

            Item {
                implicitWidth: 24
                implicitHeight: 24

                IconImage {
                    anchors.fill: parent
                    visible: row.glyph === 0
                    asynchronous: true
                    source: row.glyph === 0 ? root.iconOf(row.entryItem) : ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: row.glyph !== 0
                    text: Theme.g(row.glyph)
                    color: row.current ? Theme.on_primary : Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                }
            }

            // files: name over folder; everything else: title then a dimmer description
            Column {
                Layout.fillWidth: true
                visible: row.entryItem.kind === "file"

                Text {
                    width: parent.width
                    text: row.entryItem.title
                    elide: Text.ElideMiddle
                    color: row.current ? Theme.on_primary : Theme.on_surface
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                }
                Text {
                    width: parent.width
                    text: row.entryItem.sub
                    elide: Text.ElideMiddle
                    color: row.current ? Qt.alpha(Theme.on_primary, 0.7) : Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
            }
            Text {
                visible: row.entryItem.kind !== "file"
                Layout.fillWidth: row.entryItem.sub === ""
                Layout.maximumWidth: row.width * 0.6
                text: row.entryItem.kind === "cmd" ? row.entryItem.title.replace(/\n/g, " ⏎ ") : row.entryItem.title
                elide: Text.ElideRight
                maximumLineCount: 1
                color: row.current ? Theme.on_primary : Theme.on_surface
                font.family: row.entryItem.kind === "cmd" || row.entryItem.kind === "run" ? Theme.fontFamily : Theme.uiFont
                font.pixelSize: 15
            }
            Text {
                Layout.fillWidth: true
                visible: row.entryItem.kind !== "file" && row.entryItem.sub !== ""
                text: row.entryItem.sub
                elide: Text.ElideRight
                color: row.current ? Qt.alpha(Theme.on_primary, 0.7) : Theme.on_surface_variant
                font.family: Theme.uiFont
                font.pixelSize: 13
            }
            Text {
                visible: row.entryItem.kind === "file"
                text: row.entryItem.modified ? root.ago(row.entryItem.modified) : ""
                color: row.current ? Theme.on_primary : Theme.outline
                font.family: Theme.uiFont
                font.pixelSize: 13
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    if (row.entryItem.kind === "app")
                        root.openCtx(row.entryItem.entry, rowMouse, event.x, event.y, false);
                } else
                    root.activate(row.entryItem);
            }
        }
    }

    component AppTile: Rectangle {
        id: tile

        property var entry

        width: 76
        height: 80
        radius: 12
        color: tileMouse.containsMouse ? Theme.surface_container_high : "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 6

            IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: 36
                asynchronous: true
                source: Quickshell.iconPath(tile.entry.icon, "application-x-executable")
            }
            Text {
                width: 70
                horizontalAlignment: Text.AlignHCenter
                text: tile.entry.name
                elide: Text.ElideRight
                color: Theme.on_surface
                font.family: Theme.uiFont
                font.pixelSize: 13
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => event.button === Qt.RightButton ? root.openCtx(tile.entry, tileMouse, event.x, event.y, false) : root.activate({
                    kind: "app",
                    entry: tile.entry
                })
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
            font.family: Theme.uiFont
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
