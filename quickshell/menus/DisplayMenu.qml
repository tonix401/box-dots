import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs

// Display arrangement, like Windows' Win+P: every output Hyprland knows (`hyprctl monitors all`, so
// disabled ones too) as a scaled picture of the layout. Extend lines them up left to right in the
// order shown, aligned at the top, center or bottom; Mirror shows the selected one on all others;
// Only one turns the others off. The picked display's resolution and scale are set in the row under
// the picture. Applied live with `hyprctl eval`, so hyprland.lua's monitor rules are back after a
// reload. Same box as the share menu. Keys: Tab / 1-3 switch tabs, ←/→ (H/L) pick, Shift+←/→ move
// the picked one, T/C/B align, [ / ] resolution, - / + scale, Enter applies, Esc closes.
PanelWindow {
    id: root

    readonly property var tabs: [
        {
            label: "Extend",
            glyph: 0xf037a // monitor-multiple
        },
        {
            label: "Mirror",
            glyph: 0xf11fd // mirror
        },
        {
            label: "Only one",
            glyph: 0xf0379 // monitor
        }
    ]
    readonly property var aligns: [
        {
            key: "top",
            label: "Top",
            glyph: 0xf11c7
        },
        {
            key: "center",
            label: "Center",
            glyph: 0xf11c6
        },
        {
            key: "bottom",
            label: "Bottom",
            glyph: 0xf11c5
        }
    ]

    property int tab: 0
    // Scales offered, kept to the ones that give a whole-pixel logical size (Hyprland wants that).
    readonly property var scaleSteps: [0.5, 0.6, 0.75, 0.8, 1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.25, 2.5, 3]

    property var monitors: ({}) // name -> {name, description, width, height, rate, mode, modes, lw, lh, scale, disabled, mirrorOf}
    property var order: [] // names, left to right
    property string align: "top"
    property int selected: 0 // index into order
    property string error: ""

    readonly property int count: order.length
    readonly property var layout: arrange(order, align)
    readonly property var current: monitors[order[selected]] ?? null
    readonly property var currentScales: current ? scalesFor(current) : []

    // Fills in the mode string and the logical size: the mode over the scale, turned for 90°/270°.
    function sized(m) {
        m.mode = `${m.width}x${m.height}@${m.rate.toFixed(3)}`;
        m.lw = (m.turned ? m.height : m.width) / m.scale;
        m.lh = (m.turned ? m.width : m.height) / m.scale;
        return m;
    }

    // availableModes as distinct resolutions, smallest first, each with its refresh rates.
    function modesOf(m) {
        const out = [];
        for (const s of m.availableModes ?? []) {
            const mm = s.match(/^(\d+)x(\d+)@([\d.]+)/);
            if (!mm)
                continue;
            const w = Number(mm[1]), h = Number(mm[2]), rate = Number(mm[3]);
            let r = out.find(o => o.w === w && o.h === h);
            if (!r)
                out.push(r = {
                    w: w,
                    h: h,
                    rates: []
                });
            if (!r.rates.some(x => Math.abs(x - rate) < 0.01))
                r.rates.push(rate);
        }
        return out.sort((a, b) => a.w * a.h - b.w * b.h || a.w - b.w);
    }

    function scaleFits(m, s) {
        const whole = v => Math.abs(v - Math.round(v)) < 0.01;
        return whole(m.width / s) && whole(m.height / s);
    }

    // The steps that fit the monitor's resolution, plus its current scale when that isn't one.
    function scalesFor(m) {
        const out = scaleSteps.filter(s => scaleFits(m, s));
        if (!out.some(s => Math.abs(s - m.scale) < 0.001))
            out.push(m.scale);
        return out.sort((a, b) => a - b);
    }

    function updated(name, change) {
        const all = Object.assign({}, monitors);
        all[name] = sized(Object.assign({}, all[name], change));
        monitors = all;
        error = "";
    }

    // Steps the picked monitor through its resolutions, keeping the refresh rate when the new one
    // offers it (else its fastest) and the scale when it still fits (else the nearest that does).
    function stepResolution(dir) {
        const m = current;
        if (!m || m.modes.length === 0)
            return;
        const at = m.modes.findIndex(r => r.w === m.width && r.h === m.height);
        const r = m.modes[Math.max(0, Math.min(m.modes.length - 1, at + dir))];
        if (at >= 0 && r === m.modes[at])
            return;
        const rate = r.rates.find(x => Math.abs(x - m.rate) < 0.5) ?? Math.max(...r.rates);
        const fits = scaleSteps.filter(s => scaleFits({
                    width: r.w,
                    height: r.h
                }, s));
        const scale = fits.some(s => Math.abs(s - m.scale) < 0.001) ? m.scale : fits.reduce((a, b) => Math.abs(b - m.scale) < Math.abs(a - m.scale) ? b : a, 1);
        updated(m.name, {
            width: r.w,
            height: r.h,
            rate: rate,
            scale: scale
        });
    }

    function stepScale(dir) {
        const m = current;
        if (!m)
            return;
        const ss = currentScales;
        const at = ss.findIndex(s => Math.abs(s - m.scale) < 0.001);
        const s = ss[Math.max(0, Math.min(ss.length - 1, at + dir))];
        if (s !== m.scale)
            updated(m.name, {
                scale: s
            });
    }

    function percent(s) {
        return `${Math.round(s * 100)}%`;
    }

    function parse(list) {
        const byName = {};
        const names = {}; // mirrorOf is the mirrored monitor's id
        for (const m of list)
            names[m.id] = m.name;
        for (const m of list) {
            let w = m.width, h = m.height, rate = m.refreshRate;
            if (!w || !h) {
                // never enabled this session: the first listed mode, which is the preferred one
                const mm = (m.availableModes?.[0] ?? "1920x1080@60Hz").match(/^(\d+)x(\d+)@([\d.]+)/);
                w = Number(mm[1]);
                h = Number(mm[2]);
                rate = Number(mm[3]);
            }
            byName[m.name] = sized({
                name: m.name,
                description: m.description || `${m.make} ${m.model}`,
                width: w,
                height: h,
                rate: rate,
                modes: modesOf(m),
                scale: m.scale > 0 ? m.scale : 1,
                turned: m.transform % 2 === 1,
                x: m.x,
                y: m.y,
                disabled: m.disabled,
                mirrorOf: m.mirrorOf && m.mirrorOf !== "none" ? names[m.mirrorOf] ?? m.mirrorOf : ""
            });
        }
        return byName;
    }

    // The draft's positions in layout pixels: side by side in `names` order, aligned by `how`.
    function arrange(names, how) {
        const ms = names.map(n => monitors[n]).filter(m => m);
        const maxH = Math.max(0, ...ms.map(m => m.lh));
        let x = 0;
        return ms.map(m => {
            const y = how === "bottom" ? maxH - m.lh : how === "center" ? (maxH - m.lh) / 2 : 0;
            const r = {
                name: m.name,
                x: Math.round(x),
                y: Math.round(y),
                w: m.lw,
                h: m.lh
            };
            x += m.lw;
            return r;
        });
    }

    function load(list) {
        monitors = parse(list);
        const all = Object.values(monitors);
        const on = all.filter(m => !m.disabled && !m.mirrorOf);
        // current order: by x, the ones not in the layout last
        order = on.sort((a, b) => a.x - b.x).concat(all.filter(m => m.disabled || m.mirrorOf)).map(m => m.name);
        // current alignment, when the enabled ones share an edge or a center line
        const same = f => on.every(m => Math.abs(f(m) - f(on[0])) < 1);
        align = on.length < 2 || same(m => m.y) ? "top" : same(m => m.y + m.lh) ? "bottom" : same(m => m.y + m.lh / 2) ? "center" : "top";
        // current mode
        const mirrored = all.find(m => m.mirrorOf);
        const focused = order.indexOf(Hyprland.focusedMonitor?.name ?? "");
        if (mirrored) {
            tab = 1;
            selected = Math.max(0, order.indexOf(mirrored.mirrorOf));
        } else if (all.some(m => m.disabled) && on.length === 1) {
            tab = 2;
            selected = order.indexOf(on[0].name);
        } else {
            tab = 0;
            selected = Math.max(0, focused);
        }
    }

    function switchTab(t) {
        tab = (t + tabs.length) % tabs.length;
        error = "";
    }

    function pick(i) {
        selected = Math.max(0, Math.min(count - 1, i));
    }

    // Moves the monitor at `from` to `to` in the order; the selection follows it.
    function moveTo(from, to) {
        to = Math.max(0, Math.min(count - 1, to));
        if (from === to || from < 0 || from >= count)
            return;
        const o = order.slice();
        const [name] = o.splice(from, 1);
        o.splice(to, 0, name);
        order = o;
        selected = to;
        error = "";
    }

    function lua(spec) {
        const fields = Object.entries(spec).map(([k, v]) => `${k} = ${typeof v === "string" ? JSON.stringify(v) : v}`);
        return `hl.monitor({ ${fields.join(", ")} })`;
    }

    // A rule for an output keeps an earlier rule's mirror or disabled unless it says otherwise.
    function rule(name, position, extra) {
        return Object.assign({
            output: name,
            mode: monitors[name].mode,
            position: position,
            scale: Number(monitors[name].scale.toFixed(6)),
            disabled: false,
            mirror: ""
        }, extra);
    }

    function apply() {
        const src = order[selected];
        if (!src)
            return;
        let specs;
        if (tab === 0) {
            specs = layout.map(r => rule(r.name, `${r.x}x${r.y}`));
        } else {
            specs = [rule(src, "0x0")].concat(order.filter(n => n !== src).map(n => tab === 1 ? rule(n, "auto", {
                        mirror: src
                    }) : {
                        output: n,
                        disabled: true
                    }));
        }
        error = "";
        applier.command = ["hyprctl", "eval", specs.map(lua).join("; ")];
        applier.running = true;
    }

    Process {
        command: ["hyprctl", "monitors", "all", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.load(JSON.parse(text));
                } catch (e) {
                    root.error = "Couldn't read the monitors from hyprctl";
                }
            }
        }
    }

    Process {
        id: applier

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out === "ok")
                    Menus.close();
                else
                    root.error = out || "hyprctl eval failed";
            }
        }
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

    // A pill button in the footer.
    component PillButton: Rectangle {
        id: pill

        property string label
        property int glyph: 0
        property bool primary: false
        property bool ready: true
        signal clicked

        Layout.preferredWidth: pillRow.implicitWidth + (primary ? 40 : 36)
        Layout.fillHeight: true
        radius: 18
        opacity: ready ? 1 : 0.4
        color: primary ? (pillMouse.containsMouse && ready ? Qt.lighter(Theme.primary, 1.1) : Theme.primary) : pillMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                visible: pill.glyph !== 0
                text: Theme.g(pill.glyph)
                color: pill.primary ? Theme.on_primary : Theme.on_surface
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
            Text {
                text: pill.label
                color: pill.primary ? Theme.on_primary : Theme.on_surface
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: pill.primary ? Font.Medium : Font.Normal
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (pill.ready)
                pill.clicked()
        }
    }

    // ‹ value › in a pill, for stepping through a short list.
    component Stepper: Rectangle {
        id: stepper

        property string label
        property bool canDown: true
        property bool canUp: true
        signal down
        signal up

        radius: 12
        color: Theme.surface_container_high

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Repeater {
                model: [-1, 0, 1]

                Item {
                    id: cell

                    required property int modelData
                    readonly property bool arrow: modelData !== 0
                    readonly property bool ready: modelData < 0 ? stepper.canDown : stepper.canUp

                    Layout.preferredWidth: arrow ? 32 : -1
                    Layout.fillWidth: !arrow
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        visible: cell.arrow
                        radius: 9
                        opacity: cell.ready ? 1 : 0.35
                        color: stepMouse.containsMouse && cell.ready ? Theme.surface_container_highest : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: Theme.g(cell.modelData < 0 ? 0xf0141 : 0xf0142) // chevron-left / chevron-right
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: stepMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: cell.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (cell.ready)
                                cell.modelData < 0 ? stepper.down() : stepper.up()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !cell.arrow
                        text: stepper.label
                        color: Theme.on_surface
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    Rectangle {
        id: box

        anchors.centerIn: parent
        scale: Theme.popoutScale // laid out at full size, smaller on small screens
        width: 900
        height: 18 + 44 + 16 + 40 + 16 + 484 + 16 + 36 + 18
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
                const k = event.key, shift = event.modifiers & Qt.ShiftModifier;
                const left = k === Qt.Key_Left || k === Qt.Key_H, right = k === Qt.Key_Right || k === Qt.Key_L;
                if (k === Qt.Key_Escape)
                    Menus.close();
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                    root.apply();
                else if (k === Qt.Key_Tab)
                    root.switchTab(root.tab + 1);
                else if (k === Qt.Key_Backtab)
                    root.switchTab(root.tab - 1);
                else if (k >= Qt.Key_1 && k <= Qt.Key_3)
                    root.switchTab(k - Qt.Key_1);
                else if ((left || right) && shift)
                    root.moveTo(root.selected, root.selected + (right ? 1 : -1));
                else if (left || right)
                    root.pick(root.selected + (right ? 1 : -1));
                else if (k === Qt.Key_T)
                    root.align = "top";
                else if (k === Qt.Key_C)
                    root.align = "center";
                else if (k === Qt.Key_B)
                    root.align = "bottom";
                else if (k === Qt.Key_BracketLeft || k === Qt.Key_BracketRight)
                    root.stepResolution(k === Qt.Key_BracketRight ? 1 : -1);
                else if (k === Qt.Key_Minus || k === Qt.Key_Underscore)
                    root.stepScale(-1);
                else if (k === Qt.Key_Plus || k === Qt.Key_Equal)
                    root.stepScale(1);
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
                        text: Theme.g(0xf042e) // projector
                        color: Theme.on_primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Project your screen"
                        color: Theme.on_surface
                        font.family: Theme.uiFont
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                    Text {
                        text: "Arrange, mirror or pick which displays to use."
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

            // ── content: the layout picture over the picked display's settings and the align row (or a hint) ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 484
                spacing: 14

                Rectangle {
                    id: stage

                    readonly property int gap: 12 // between tiles, so neighbours stay apart in the picture
                    readonly property real totalW: root.layout.reduce((s, r) => s + r.w, 0)
                    readonly property real maxH: Math.max(1, ...root.layout.map(r => r.h + r.y))
                    readonly property real factor: root.count === 0 ? 1 : Math.min((width - 48 - gap * (root.count - 1)) / Math.max(1, totalW), (height - 48) / maxH)
                    readonly property real originX: (width - totalW * factor - gap * (root.count - 1)) / 2
                    readonly property real originY: (height - maxH * factor) / 2

                    property int dragIndex: -1
                    property real dragDx: 0

                    // where the dragged tile would land: past every other tile whose center it passed
                    function dropIndex() {
                        const r = root.layout[dragIndex];
                        const center = originX + r.x * factor + dragIndex * gap + dragDx + r.w * factor / 2;
                        let i = 0;
                        root.layout.forEach((o, j) => {
                            if (j !== dragIndex && originX + o.x * factor + j * gap + o.w * factor / 2 < center)
                                i++;
                        });
                        return i;
                    }

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Theme.surface_container_high

                    Text {
                        anchors.centerIn: parent
                        visible: root.count === 0
                        text: root.error === "" ? "Looking for displays…" : "No displays"
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                    }

                    Repeater {
                        model: root.layout

                        Item {
                            id: tile

                            required property var modelData
                            required property int index
                            readonly property var mon: root.monitors[modelData.name]
                            readonly property var shot: Quickshell.screens.find(s => s.name === modelData.name) ?? null
                            readonly property bool isSelected: index === root.selected
                            readonly property bool dragging: stage.dragIndex === index
                            // dimmed in Mirror / Only one when not the picked one
                            readonly property bool off: root.tab === 2 && !isSelected
                            readonly property bool mirrors: root.tab === 1 && !isSelected

                            x: stage.originX + modelData.x * stage.factor + index * stage.gap + (dragging ? stage.dragDx : 0)
                            y: stage.originY + modelData.y * stage.factor
                            z: dragging ? 1 : 0
                            width: modelData.w * stage.factor
                            height: modelData.h * stage.factor

                            Behavior on x {
                                enabled: !tile.dragging
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on y {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }

                            ClippingRectangle {
                                id: preview

                                anchors.fill: parent
                                radius: 8
                                color: tileMouse.containsMouse && !tile.isSelected ? Theme.surface_container_highest : Theme.surface

                                ScreencopyView {
                                    id: capture

                                    anchors.fill: parent
                                    captureSource: tile.mon && !tile.mon.disabled ? tile.shot : null
                                    live: true
                                    paintCursor: false
                                    visible: hasContent
                                    opacity: tile.off ? 0.25 : 1
                                }

                                // disabled or not captured: a big glyph instead
                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -12
                                    visible: !capture.hasContent
                                    text: Theme.g(tile.mon?.disabled ? 0xf0d90 : 0xf0379) // monitor-off / monitor
                                    color: Theme.outline
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.min(56, tile.height / 3)
                                }

                                // what the draft does to it in Mirror / Only one
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: tile.off || tile.mirrors
                                    width: stateRow.implicitWidth + 24
                                    height: 30
                                    radius: 15
                                    color: Qt.alpha(Theme.surface, 0.85)

                                    Row {
                                        id: stateRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: Theme.g(tile.off ? 0xf0d90 : 0xf11fd)
                                            color: Theme.primary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 15
                                        }
                                        Text {
                                            text: tile.off ? "Off" : `Mirrors ${root.order[root.selected] ?? ""}`
                                            color: Theme.on_surface
                                            font.family: Theme.uiFont
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // position badge, top left
                                Rectangle {
                                    x: 8
                                    y: 8
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: tile.isSelected ? Theme.primary : Qt.alpha(Theme.surface, 0.85)

                                    Text {
                                        anchors.centerIn: parent
                                        text: tile.index + 1
                                        color: tile.isSelected ? Theme.on_primary : Theme.on_surface
                                        font.family: Theme.uiFont
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                }

                                // caption bar along the bottom
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: captionCol.implicitHeight + 12
                                    color: Qt.alpha(Theme.surface, 0.85)

                                    Column {
                                        id: captionCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        RowLayout {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                text: tile.modelData.name
                                                elide: Text.ElideRight
                                                color: tile.isSelected ? Theme.primary : Theme.on_surface
                                                font.family: Theme.uiFont
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: tile.mon ? `${tile.mon.width}×${tile.mon.height}` + (tile.mon.scale !== 1 ? ` · ${root.percent(tile.mon.scale)}` : "") : ""
                                                color: Theme.outline
                                                font.family: Theme.uiFont
                                                font.pixelSize: 11
                                            }
                                        }
                                        Text {
                                            width: parent.width
                                            text: tile.mon?.description ?? ""
                                            elide: Text.ElideRight
                                            color: Theme.on_surface_variant
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }

                            // selection ring
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -3
                                radius: 11
                                color: "transparent"
                                border.width: 2
                                border.color: Theme.primary
                                visible: tile.isSelected
                            }

                            // click picks; dragging sideways reorders (Extend only)
                            MouseArea {
                                id: tileMouse

                                property real pressX: 0

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: stage.dragIndex >= 0 ? Qt.ClosedHandCursor : root.tab === 0 ? Qt.OpenHandCursor : Qt.PointingHandCursor
                                preventStealing: true
                                onPressed: mouse => {
                                    root.pick(tile.index);
                                    pressX = mapToItem(stage, mouse.x, mouse.y).x;
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed || root.tab !== 0)
                                        return;
                                    const dx = mapToItem(stage, mouse.x, mouse.y).x - pressX;
                                    if (stage.dragIndex < 0 && Math.abs(dx) < 6)
                                        return;
                                    stage.dragIndex = tile.index;
                                    stage.dragDx = dx;
                                }
                                onReleased: {
                                    if (stage.dragIndex < 0)
                                        return;
                                    const from = stage.dragIndex, to = stage.dropIndex();
                                    stage.dragIndex = -1;
                                    stage.dragDx = 0;
                                    root.moveTo(from, to);
                                }
                                onDoubleClicked: if (root.tab !== 0)
                                    root.apply()
                            }
                        }
                    }
                }

                // the picked display's resolution and scale
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 40
                    spacing: 14
                    opacity: root.current ? 1 : 0.4

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.current ? root.current.name : "No display"
                        color: Theme.on_surface
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        text: "Resolution"
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                    }

                    Stepper {
                        Layout.preferredWidth: 230
                        Layout.fillHeight: true
                        label: root.current ? `${root.current.width}×${root.current.height} @ ${Math.round(root.current.rate)} Hz` : "—"
                        canDown: !!root.current && root.current.modes.findIndex(r => r.w === root.current.width && r.h === root.current.height) !== 0
                        canUp: !!root.current && root.current.modes.findIndex(r => r.w === root.current.width && r.h === root.current.height) < root.current.modes.length - 1
                        onDown: root.stepResolution(-1)
                        onUp: root.stepResolution(1)
                    }

                    Text {
                        text: "Scale"
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                    }

                    Stepper {
                        Layout.preferredWidth: 140
                        Layout.fillHeight: true
                        label: root.current ? root.percent(root.current.scale) : "—"
                        canDown: !!root.current && root.current.scale > root.currentScales[0] + 0.001
                        canUp: !!root.current && root.current.scale < root.currentScales[root.currentScales.length - 1] - 0.001
                        onDown: root.stepScale(-1)
                        onUp: root.stepScale(1)
                    }
                }

                // align control in Extend, a hint otherwise
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false // layouts fill by default and would squeeze the picture
                    Layout.preferredHeight: 40
                    spacing: 14

                    Text {
                        text: root.tab === 0 ? "Align" : root.tab === 1 ? "Pick the display the others show" : "Pick the display to keep on"
                        color: Theme.on_surface_variant
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: root.tab === 0
                        Layout.preferredWidth: 360
                        Layout.fillHeight: true
                        radius: 12
                        color: Theme.surface_container_high

                        Row {
                            id: alignRow
                            anchors.fill: parent
                            anchors.margins: 4

                            Repeater {
                                model: root.aligns

                                Rectangle {
                                    id: alignButton

                                    required property var modelData
                                    readonly property bool active: modelData.key === root.align

                                    width: alignRow.width / root.aligns.length
                                    height: alignRow.height
                                    radius: 9
                                    color: active ? Theme.primary : alignMouse.containsMouse ? Theme.surface_container_highest : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: Theme.g(alignButton.modelData.glyph)
                                            color: alignButton.active ? Theme.on_primary : Theme.primary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 16
                                        }
                                        Text {
                                            text: alignButton.modelData.label
                                            color: alignButton.active ? Theme.on_primary : Theme.on_surface
                                            font.family: Theme.uiFont
                                            font.pixelSize: 13
                                        }
                                    }

                                    MouseArea {
                                        id: alignMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.align = alignButton.modelData.key
                                    }
                                }
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

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.error !== "" ? root.error : root.tab === 0 ? "Drag or Shift+←/→ to reorder · T/C/B align · [ ] resolution · −/+ scale · back to hyprland.lua on reload" : "←/→ to pick · [ ] resolution · −/+ scale · back to hyprland.lua on reload"
                    color: root.error !== "" ? Theme.error : Theme.outline
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                PillButton {
                    label: "Cancel"
                    onClicked: Menus.close()
                }

                PillButton {
                    primary: true
                    ready: root.count > 0 && !applier.running
                    glyph: 0xf012c // check
                    label: "Apply"
                    onClicked: root.apply()
                }
            }
        }
    }
}
