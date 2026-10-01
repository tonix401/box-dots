import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// The last four weeks (Monday to Sunday, this week last) as a grid of days with a dot per habit,
// on the desktop right of the todo list. A check-in is an all-day event titled like the habit in
// the "Habits" Google calendar (Dcal.habitsCalendarId), so it syncs to the phone and one added
// there counts too. Next to each habit, the share of the last 30 days with a check-in, and an
// arrow for whether the last 7 days are ahead of, behind or level with that.
// Clicking one of today's dots (drawn bigger) adds or removes today's event;
// past days only show what was logged: the habit's icon, or a thin grey ring when missed. Clicking a habit below the grid edits it, + adds one.
// Arrows or the mouse wheel move by a week; clicking the title (or a minute without the pointer
// on it) goes back to this week.
// The habits themselves (name, glyph, color role, old names) live in the state dir's habits.json.
PanelWindow {
    id: root

    readonly property int pad: 8
    readonly property int gap: 4 // between the day cells
    readonly property int dot: 14
    readonly property int dotGap: 6
    readonly property var colors: ["primary", "secondary", "tertiary", "error", "tertiary_fixed"]

    property var habits: [] // [{name, glyph, color, aliases}]
    property var events: [] // the Habits calendar's events in the shown weeks
    property var pending: ({}) // "habit:yyyy-MM-dd" -> done, for clicks not answered yet
    property int editing: -1 // habit index in the editor, -2 for a new one
    property int weekOffset: 0

    property string error: ""

    readonly property string today: Qt.formatDate(clock.date, "yyyy-MM-dd")
    // Monday three weeks before the shown last week.
    readonly property date firstDay: {
        const t = parseDay(today);
        return new Date(t.getFullYear(), t.getMonth(), t.getDate() - (t.getDay() + 6) % 7 + 7 * (weekOffset - 3));
    }
    readonly property var days: Array.from({
        length: 28
    }, (_, i) => new Date(firstDay.getFullYear(), firstDay.getMonth(), firstDay.getDate() + i))
    readonly property bool ready: Dcal.connected && Dcal.habitsCalendarId !== ""
    readonly property var done: checkIns(events, habits)
    // The Habits calendar's events in the last 30 days, for the legend's percentages, whichever
    // weeks are shown.
    property var recentEvents: []
    readonly property var recentDone: checkIns(recentEvents, habits)

    function parseDay(s) {
        const [y, m, d] = s.slice(0, 10).split("-").map(Number);
        return new Date(y, m - 1, d);
    }
    function dayKey(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }
    function norm(s) {
        return (s ?? "").trim().toLowerCase();
    }
    function colorOf(role) {
        return Theme[role] ?? Theme.primary;
    }
    function glyphOf(habit) {
        return habit.glyph || Array.from(habit.name)[0] || "";
    }

    // "habit:yyyy-MM-dd" -> ids of that day's check-in events. Events match a habit by title,
    // against its name and the names it had before.
    function checkIns(events, habits) {
        const byName = {};
        habits.forEach((h, i) => [h.name].concat(h.aliases ?? []).forEach(n => byName[norm(n)] = i));
        const out = {};
        for (const ev of events) {
            const h = byName[norm(ev.summary)];
            if (h === undefined || ev.status === "cancelled")
                continue;
            // All-day events carry their date as UTC midnight.
            const key = h + ":" + (ev.allDay ? ev.start.slice(0, 10) : dayKey(new Date(ev.start)));
            (out[key] = out[key] ?? []).push(ev.id);
        }
        return out;
    }
    function isDone(h, day) {
        const key = h + ":" + day;
        return key in pending ? pending[key] : key in done;
    }
    // Share of the last n days (up to 30) with a check-in. Today only counts once it is ticked, so
    // the number doesn't drop every morning: until then the window is the n days before today.
    function rate(h, n) {
        const t = parseDay(today);
        const recently = day => {
            const key = h + ":" + day;
            return key in pending ? pending[key] : key in recentDone;
        };
        const start = recently(today) ? 0 : 1;
        let k = 0;
        for (let i = start; i < start + n; i++)
            if (recently(dayKey(new Date(t.getFullYear(), t.getMonth(), t.getDate() - i))))
                k++;
        return k / n;
    }
    // The last 7 days against the last 30: 1 ahead, -1 behind, 0 within 10 points.
    function trend(h) {
        const d = rate(h, 7) - rate(h, 30);
        return d >= 0.1 ? 1 : d <= -0.1 ? -1 : 0;
    }

    function load() {
        if (!ready) {
            events = [];
            return;
        }
        const from = firstDay;
        const to = new Date(from.getFullYear(), from.getMonth(), from.getDate() + 28);
        Dcal.request("events.list", {
            from: from.toISOString(),
            to: to.toISOString(),
            limit: 1000
        }, result => {
            if (from.getTime() !== root.firstDay.getTime())
                return; // older weeks answered late
            root.events = (result?.events ?? []).filter(ev => ev.calendarId === Dcal.habitsCalendarId);
        });
    }
    function loadRecent() {
        if (!ready) {
            recentEvents = [];
            return;
        }
        const day = today;
        const t = parseDay(day);
        Dcal.request("events.list", {
            from: new Date(t.getFullYear(), t.getMonth(), t.getDate() - 30).toISOString(),
            to: new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1).toISOString(),
            limit: 1000
        }, result => {
            if (day !== root.today)
                return; // answered after midnight
            root.recentEvents = (result?.events ?? []).filter(ev => ev.calendarId === Dcal.habitsCalendarId);
        });
    }

    function setPending(key, value) {
        const p = Object.assign({}, pending);
        if (value === undefined)
            delete p[key];
        else
            p[key] = value;
        pending = p;
    }
    function fail(key, message) {
        setPending(key, undefined);
        error = message;
    }

    function toggle(h, day) {
        const key = h + ":" + day;
        if (key in pending || !ready || day !== today)
            return;
        error = "";
        const [y, m, d] = day.split("-").map(Number);
        let sent;
        if (isDone(h, day)) {
            setPending(key, false);
            const ids = done[key];
            let left = ids.length;
            for (const id of ids)
                sent = Dcal.request("events.delete", {
                    id: id
                }, () => {
                    root.events = root.events.filter(ev => ev.id !== id);
                    root.recentEvents = root.recentEvents.filter(ev => ev.id !== id);
                    if (--left === 0)
                        root.setPending(key, undefined);
                }, message => root.fail(key, message));
        } else {
            setPending(key, true);
            sent = Dcal.request("events.create", {
                calendarId: Dcal.habitsCalendarId,
                summary: habits[h].name,
                start: new Date(Date.UTC(y, m - 1, d)).toISOString(),
                end: new Date(Date.UTC(y, m - 1, d + 1)).toISOString(),
                allDay: true
            }, result => {
                const ev = Object.assign({
                    calendarId: Dcal.habitsCalendarId
                }, result);
                root.events = root.events.concat([ev]);
                root.recentEvents = root.recentEvents.concat([ev]);
                root.setPending(key, undefined);
            }, message => root.fail(key, message));
        }
        if (!sent)
            fail(key, "dcal is not running");
    }

    function saveHabits(list) {
        habits = list;
        habitsFile.setText(JSON.stringify(list, null, 2) + "\n");
    }

    onFirstDayChanged: {
        pending = {};
        load();
    }
    onTodayChanged: loadRecent()
    onReadyChanged: {
        load();
        loadRecent();
    }
    Component.onCompleted: {
        load();
        loadRecent();
    }

    Connections {
        target: Dcal
        function onRevisionChanged() {
            root.load();
            root.loadRecent();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    Timer {
        interval: 60000
        running: root.weekOffset !== 0 && root.editing === -1 && !hover.hovered
        onTriggered: root.weekOffset = 0
    }

    FileView {
        id: habitsFile
        path: Quickshell.statePath("habits.json")
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.habits = JSON.parse(text());
            } catch (e) {}
        }
    }

    // Placed by shell.qml (right of the todo list), which sets `room`: how far the window (and the
    // dark backdrop) reaches past each edge of the panel, the last `fade` px on the right fading out. The
    // panel fills the window's height and is as wide as it is tall.
    property var room: ({
            left: 0,
            top: 0,
            right: 0,
            bottom: 0
        })
    property int fade: 0
    readonly property int size: Math.max(0, height - room.top - room.bottom)

    implicitWidth: room.left + size + room.right
    implicitHeight: 600
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-habits"
    WlrLayershell.keyboardFocus: editing !== -1 || hover.hovered ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Only the panel takes clicks, not the backdrop around it.
    mask: Region {
        item: panel
    }

    Backdrop {
        fade: root.fade
    }

    Item {
        id: panel

        x: root.room.left
        y: root.room.top
        width: root.size
        height: root.size

        HoverHandler {
            id: hover
        }

        // Clicking anywhere else on the panel closes the editor.
        MouseArea {
            anchors.fill: parent
            onClicked: root.editing = -1
        }

        ColumnLayout {
            id: content

            x: root.pad
            y: root.pad
            width: parent.width - 2 * root.pad
            height: parent.height - 2 * root.pad
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Habits"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium

                    // Only away from this week, where clicking does something.
                    MouseArea {
                        anchors.fill: parent
                        visible: root.weekOffset !== 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.weekOffset = 0
                    }
                }
                Text {
                    text: Qt.formatDate(root.days[0], "d MMM") + " – " + Qt.formatDate(root.days[27], "d MMM")
                    color: Theme.on_surface
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    visible: !Dcal.connected
                    text: "dcal is not running"
                    color: Theme.on_surface
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                GlyphButton {
                    glyph: 0xf0415
                    onClicked: root.editing = -2
                }
                GlyphButton {
                    glyph: 0xf0141
                    onClicked: root.weekOffset--
                }
                GlyphButton {
                    glyph: 0xf0142
                    onClicked: root.weekOffset++
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: {
                    if (root.error !== "")
                        return root.error;
                    if (Dcal.connected && Dcal.habitsCalendarId === "")
                        return "Create a Google calendar named “Habits” to log check-ins to";
                    if (root.habits.length === 0)
                        return "Add a habit with +";
                    return "";
                }
                wrapMode: Text.Wrap
                color: root.error !== "" ? Theme.error : Theme.on_surface_variant
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            // The day grid, or the editor in its place.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: grid

                    readonly property real cellWidth: (width - 6 * root.gap) / 7
                    readonly property real cellHeight: (height - 18 - 3 * root.gap) / 4

                    anchors.fill: parent
                    visible: root.editing === -1

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse
                        onWheel: event => root.weekOffset += event.angleDelta.y > 0 ? -1 : 1
                    }

                    Repeater {
                        model: 7

                        Text {
                            required property int index

                            x: index * (grid.cellWidth + root.gap)
                            width: grid.cellWidth
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatDate(root.days[index], "ddd")
                            color: Theme.on_surface
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    Repeater {
                        model: root.days

                        DayCell {
                            x: index % 7 * (grid.cellWidth + root.gap)
                            y: 18 + Math.floor(index / 7) * (grid.cellHeight + root.gap)
                            width: grid.cellWidth
                            height: grid.cellHeight
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: root.editing !== -1
                    visible: active
                    sourceComponent: Editor {
                        index: root.editing
                    }
                }
            }

            // Which dot is which habit, with how many of the last 30 days have a check-in and whether the
            // last 7 are ahead of that.
            Grid {
                id: legend

                Layout.fillWidth: true
                visible: root.habits.length > 0
                columns: 2
                columnSpacing: 12

                Repeater {
                    model: root.habits

                    HabitEntry {
                        width: (legend.width - legend.columnSpacing) / 2
                    }
                }
            }
        }
    }

    component DayCell: Item {
        id: cell

        required property var modelData
        required property int index
        readonly property string day: root.dayKey(modelData)
        readonly property bool future: day > root.today
        readonly property bool isToday: day === root.today
        readonly property int dotSize: isToday ? root.dot + 4 : root.dot
        // Dots per line, and the width of the widest line, to center the dots.
        readonly property int perLine: Math.max(1, Math.floor((width - 8 + root.dotGap) / (dotSize + root.dotGap)))
        readonly property int lineWidth: Math.min(root.habits.length, perLine) * (dotSize + root.dotGap) - root.dotGap

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Qt.alpha(Theme.on_surface, cell.isToday ? 0.12 : cell.future ? 0.03 : 0.07)
            border.width: cell.isToday ? 2 : 0
            border.color: Theme.primary
        }
        Text {
            x: 7
            y: 4
            text: cell.modelData.getDate() === 1 ? Qt.formatDate(cell.modelData, "d MMM") : cell.modelData.getDate()
            color: cell.isToday ? Theme.primary : cell.future ? Theme.on_surface_variant : Theme.on_surface
            opacity: cell.future ? 0.6 : 1
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: cell.isToday ? Font.Bold : Font.Normal
        }

        Flow {
            x: (cell.width - cell.lineWidth) / 2
            y: 20 + (cell.height - 20 - height) / 2
            width: cell.lineWidth
            spacing: root.dotGap
            visible: !cell.future

            Repeater {
                model: root.habits

                Item {
                    id: dot

                    required property var modelData
                    required property int index
                    readonly property color accent: root.colorOf(modelData.color)
                    readonly property bool isDone: root.isDone(index, cell.day)

                    width: cell.dotSize
                    height: cell.dotSize

                    // Today: a filled dot when done, a ring when not. Past days: the habit's icon when
                    // done, a thin grey ring when missed.
                    Rectangle {
                        anchors.fill: parent
                        visible: cell.isToday || !dot.isDone
                        radius: width / 2
                        color: dot.isDone ? dot.accent : dotMouse.containsMouse ? Qt.alpha(dot.accent, 0.4) : "transparent"
                        border.width: dot.isDone ? 0 : cell.isToday ? 2 : 1
                        border.color: cell.isToday ? dot.accent : Theme.outline
                        opacity: root.pending[dot.index + ":" + cell.day] !== undefined ? 0.5 : 1
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !cell.isToday && dot.isDone
                        text: root.glyphOf(dot.modelData)
                        color: dot.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: dotMouse
                        anchors.fill: parent
                        anchors.margins: -2
                        // Not just disabled: a disabled MouseArea still shows its cursor.
                        visible: cell.isToday && root.ready
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle(dot.index, cell.day)
                    }
                }
            }
        }
    }

    component HabitEntry: Item {
        id: entry

        required property var modelData
        required property int index
        readonly property color accent: root.colorOf(modelData.color)

        height: 22

        MouseArea {
            id: label
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editing = root.editing === entry.index ? -1 : entry.index
        }
        Text {
            width: 20
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: root.glyphOf(entry.modelData)
            color: entry.accent
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
        Text {
            x: 26
            width: parent.width - 26 - count.width - 6
            anchors.verticalCenter: parent.verticalCenter
            text: entry.modelData.name
            elide: Text.ElideRight
            color: label.containsMouse || root.editing === entry.index ? entry.accent : Theme.on_surface
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
        Row {
            id: count

            readonly property int trend: root.trend(entry.index)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(100 * root.rate(entry.index, 30)) + "%"
                color: Theme.on_surface
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            // trending-up / -neutral / -down
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.g(count.trend > 0 ? 0xf0535 : count.trend < 0 ? 0xf0533 : 0xf0534)
                color: count.trend > 0 ? Theme.primary : count.trend < 0 ? Theme.error : Theme.on_surface_variant
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }
    }

    // Adds (index -2) or edits a habit. Enter saves, Escape cancels. Renaming keeps the old name
    // as an alias, so the check-ins already in the calendar keep counting.
    component Editor: Rectangle {
        id: editor

        property int index
        readonly property var habit: index >= 0 ? root.habits[index] : null
        property string colorName: habit?.color ?? root.colors[root.habits.length % root.colors.length]
        property bool confirmDelete: false
        property string error: ""

        function save() {
            const name = nameField.text.trim();
            const taken = root.habits.some((h, i) => i !== index && [h.name].concat(h.aliases ?? []).some(n => root.norm(n) === root.norm(name)));
            if (name === "")
                error = "Add a name";
            else if (taken)
                error = "Another habit already uses that name";
            else
                error = "";
            if (error !== "")
                return;

            const list = root.habits.slice();
            let aliases = habit?.aliases ?? [];
            if (habit && root.norm(habit.name) !== root.norm(name))
                aliases = aliases.concat([habit.name]);
            const next = {
                name: name,
                glyph: glyphField.text.trim(),
                color: colorName,
                aliases: aliases.filter(a => root.norm(a) !== root.norm(name))
            };
            if (index >= 0)
                list[index] = next;
            else
                list.push(next);
            root.saveHabits(list);
            root.editing = -1;
        }
        function remove() {
            if (!confirmDelete) {
                confirmDelete = true;
                return;
            }
            root.saveHabits(root.habits.filter((h, i) => i !== index));
            root.editing = -1;
        }

        Component.onCompleted: nameField.input.forceActiveFocus()
        // The loader keeps the editor when another habit's name is clicked.
        onIndexChanged: {
            nameField.text = habit?.name ?? "";
            glyphField.text = habit?.glyph ?? "";
            colorName = habit?.color ?? root.colors[root.habits.length % root.colors.length];
            confirmDelete = false;
            error = "";
            nameField.input.forceActiveFocus();
        }

        implicitHeight: form.implicitHeight + 24
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // keep clicks from reaching the panel below
        }

        ColumnLayout {
            id: form

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            SectionLabel {
                text: editor.index >= 0 ? "Edit habit" : "New habit"
                hint: "check-ins go to the Habits calendar"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Field {
                    id: glyphField
                    Layout.fillWidth: false
                    Layout.preferredWidth: 56
                    placeholder: "Icon"
                    text: editor.habit?.glyph ?? ""
                    onAccepted: editor.save()
                    onCancelled: root.editing = -1
                }
                Field {
                    id: nameField
                    placeholder: "Name, e.g. Chinese"
                    text: editor.habit?.name ?? ""
                    onAccepted: editor.save()
                    onCancelled: root.editing = -1
                }
                Pill {
                    Layout.preferredHeight: 30
                    text: "Color"
                    dot: root.colorOf(editor.colorName)
                    onClicked: editor.colorName = root.colors[(root.colors.indexOf(editor.colorName) + 1) % root.colors.length]
                }
            }
            Text {
                Layout.fillWidth: true
                visible: editor.error !== "" || editor.confirmDelete
                text: editor.error || "Click the bin again to remove the habit (its check-ins stay in the calendar)"
                wrapMode: Text.Wrap
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                GlyphButton {
                    visible: editor.index >= 0
                    glyph: 0xf01b4
                    size: 32
                    fg: editor.confirmDelete ? Theme.error : Theme.on_surface_variant
                    onClicked: editor.remove()
                }
                TextButton {
                    text: "Cancel"
                    onClicked: root.editing = -1
                }
                Pill {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: "Save"
                    active: true
                    onClicked: editor.save()
                }
            }
        }
    }
}
