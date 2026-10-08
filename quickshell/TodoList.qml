import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// The open tasks of dcal's task lists (Google Tasks), on the desktop below the calendar and
// styled like it. The field on top adds a task to "Meine Aufgaben" ("… @fri" gives it a due
// date); the circle completes one (clicking it again within a moment takes that back); clicking
// a task opens it for editing or deleting. The eye in the header shows completed tasks too.
PanelWindow {
    id: root

    readonly property int pad: 8

    property var tasks: []
    property bool showDone: false
    property string expanded: "" // id of the task being edited
    property bool stale: false // a reload waited for the editor to close
    property var pending: ({}) // id -> completed, for check clicks not sent yet
    property string addError: ""
    // New tasks always go to this Google Tasks list.
    readonly property string newTaskList: "Meine Aufgaben"
    readonly property string listId: Dcal.calendars.find(c => c.holdsTasks && !c.readOnly && c.name === newTaskList)?.id ?? ""
    readonly property var rows: arrange(tasks)
    readonly property int openCount: tasks.filter(t => t.status !== "completed").length
    // Changes once a day, for the due labels.
    readonly property string today: Qt.formatDate(clock.date, "yyyy-MM-dd")

    readonly property var accents: [Theme.primary, Theme.tertiary, Theme.secondary]

    function accent(calendarId) {
        const i = Dcal.calendars.findIndex(c => c.id === calendarId);
        return accents[Math.max(0, i) % accents.length];
    }
    function listName(id) {
        return Dcal.calendars.find(c => c.id === id)?.name ?? "";
    }
    function parseDay(s) {
        const [y, m, d] = s.slice(0, 10).split("-").map(Number);
        return new Date(y, m - 1, d);
    }

    function load() {
        // Rebuilding the rows would throw away what's typed in the editor.
        if (expanded !== "") {
            stale = true;
            return;
        }
        stale = false;
        Dcal.request("tasks.list", {
            includeCompleted: showDone,
            limit: 1000
        }, result => {
            const lists = Dcal.calendars.filter(c => c.holdsTasks && !c.hidden).map(c => c.id);
            root.tasks = (result?.tasks ?? []).filter(t => lists.includes(t.calendarId) && t.status !== "cancelled" && (root.showDone || t.status !== "completed"));
        });
    }

    // Open tasks by due date (undated last), then completed ones, newest first; subtasks under
    // their parent.
    function arrange(tasks) {
        const cmp = (a, b) => {
            const x = a.status === "completed", y = b.status === "completed";
            if (x !== y)
                return x ? 1 : -1;
            if (x)
                return (b.completed ?? "").localeCompare(a.completed ?? "");
            return (a.due ?? "9999").slice(0, 10).localeCompare((b.due ?? "9999").slice(0, 10)) || a.summary.localeCompare(b.summary);
        };
        const uids = tasks.map(t => t.uid);
        const out = [];
        const add = (t, depth) => {
            out.push({
                task: t,
                depth: depth
            });
            tasks.filter(c => c.parentUid === t.uid).sort(cmp).forEach(c => add(c, depth + 1));
        };
        tasks.filter(t => !uids.includes(t.parentUid)).sort(cmp).forEach(t => add(t, 0));
        return out;
    }

    // The task's due day (local midnight), null without one. Google Tasks due dates are UTC
    // midnights, like dcal's all-day events.
    function dueDate(task) {
        if (!task.due)
            return null;
        return task.allDay ? parseDay(task.due) : parseDay(Qt.formatDate(new Date(task.due), "yyyy-MM-dd"));
    }
    // Days from today to the due date, NaN without one.
    function dueIn(task) {
        const d = dueDate(task);
        return d ? Math.round((d - parseDay(today)) / 86400000) : NaN;
    }
    function dueLabel(task) {
        const n = dueIn(task), d = dueDate(task);
        if (n === 0)
            return "Today";
        if (n === 1)
            return "Tomorrow";
        if (n === -1)
            return "Yesterday";
        if (n > 1 && n < 7)
            return Qt.formatDate(d, "dddd");
        return Qt.formatDate(d, d.getFullYear() === parseDay(today).getFullYear() ? "ddd d MMM" : "ddd d MMM yyyy");
    }
    // The due date as the editor's field shows it.
    function dueText(task) {
        const d = dueDate(task);
        return d ? Qt.formatDate(d, "d.M.yyyy") : "";
    }

    // A due date typed as today/tomorrow (or heute/morgen), a weekday (next one), +N days,
    // d.m.[yyyy] or yyyy-mm-dd. Returns a UTC midnight, null for "" and undefined when unreadable.
    function parseDue(text) {
        const s = text.trim().toLowerCase();
        if (s === "")
            return null;
        const t = parseDay(today);
        const utc = (y, m, d) => {
            const x = new Date(Date.UTC(y, m - 1, d));
            return x.getUTCMonth() === m - 1 && x.getUTCDate() === d ? x : undefined;
        };
        const inDays = n => new Date(Date.UTC(t.getFullYear(), t.getMonth(), t.getDate() + n));
        if (["today", "heute"].includes(s))
            return inDays(0);
        if (["tomorrow", "morgen"].includes(s))
            return inDays(1);
        let m = /^\+(\d{1,3})$/.exec(s);
        if (m)
            return inDays(+m[1]);
        if (s.length >= 2) {
            const en = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
            const de = ["sonntag", "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag"];
            const w = en.findIndex((name, i) => name.startsWith(s) || de[i].startsWith(s));
            if (w >= 0)
                return inDays((w - t.getDay() + 6) % 7 + 1);
        }
        m = /^(\d{1,2})\.(\d{1,2})\.?(\d{2}|\d{4})?$/.exec(s);
        if (m) {
            let y = m[3] ? +m[3] : t.getFullYear();
            if (y < 100)
                y += 2000;
            const d = utc(y, +m[2], +m[1]);
            // Without a year a date that has passed means next year's.
            if (d && !m[3] && d < inDays(0))
                return utc(y + 1, +m[2], +m[1]);
            return d;
        }
        m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(s);
        if (m)
            return utc(+m[1], +m[2], +m[3]);
        return undefined;
    }

    function add(text) {
        let summary = text.trim(), due = null;
        const m = /^(.*\S)\s+@(\S+)$/.exec(summary);
        if (m) {
            summary = m[1];
            due = parseDue(m[2]);
        }
        if (summary === "")
            addError = "";
        else if (due === undefined)
            addError = "Write dates like @3.10., @tomorrow or @fri";
        else if (listId === "")
            addError = "No task list named “" + newTaskList + "”";
        else
            addError = "";
        if (summary === "" || addError !== "")
            return false;

        const params = {
            calendarId: listId,
            summary: summary
        };
        if (due) {
            params.due = due.toISOString();
            params.allDay = true;
        }
        if (!Dcal.request("tasks.create", params, () => root.load(), message => root.addError = message)) {
            addError = "dcal is not running";
            return false;
        }
        return true;
    }

    // A check click waits a moment before it is sent, so a second click can take it back.
    function toggleDone(task) {
        const p = Object.assign({}, pending);
        if (task.id in p)
            delete p[task.id];
        else
            p[task.id] = task.status !== "completed";
        pending = p;
        send.restart();
    }
    function isDone(task) {
        return task.id in pending ? pending[task.id] : task.status === "completed";
    }

    function close() {
        expanded = "";
    }

    onExpandedChanged: {
        if (expanded === "" && stale)
            load();
    }
    onShowDoneChanged: load()
    Component.onCompleted: load()

    Connections {
        target: Dcal
        function onRevisionChanged() {
            root.load();
        }
        function onCalendarsChanged() {
            root.load();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    Timer {
        id: send
        interval: 1500
        onTriggered: {
            for (const id in root.pending) {
                const completed = root.pending[id];
                Dcal.request("tasks.complete", {
                    id: id,
                    completed: completed
                }, result => {
                    // Keep the row as clicked until the reload the change triggers arrives.
                    root.tasks = root.tasks.map(t => t.id === id ? Object.assign({}, t, result) : t);
                    const p = Object.assign({}, root.pending);
                    delete p[id];
                    root.pending = p;
                    if (completed)
                        Pet.react("cheer");
                }, () => {
                    const p = Object.assign({}, root.pending);
                    delete p[id];
                    root.pending = p;
                });
            }
        }
    }

    // Placed by shell.qml (below the calendar, left of the habit tracker), which sets the panel's size
    // and `room`: how far the window (and the dark backdrop) reaches past each edge of the panel.
    // Nothing here reads the window's own size (see shell.qml).
    property int panelWidth: 420
    property int panelHeight: 400
    property var room: ({
            left: 0,
            top: 0,
            right: 0,
            bottom: 0
        })
    property int fade: 0

    implicitWidth: room.left + panelWidth + room.right
    implicitHeight: room.top + panelHeight + room.bottom
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-todo"
    // Takes the keyboard on click only while the pointer is on it, and keeps it while a task is
    // being edited or typed.
    WlrLayershell.keyboardFocus: expanded !== "" || hover.hovered || addField.input.activeFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
        width: root.panelWidth
        height: root.panelHeight

        HoverHandler {
            id: hover
        }

        // Clicking anywhere else on the panel closes the editor.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        ColumnLayout {
            x: root.pad
            y: root.pad
            width: parent.width - 2 * root.pad
            height: parent.height - 2 * root.pad
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "To do"
                    color: Theme.primary
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                Text {
                    text: root.openCount === 0 ? "all done" : root.openCount + " open"
                    color: Theme.on_surface
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    visible: !Dcal.connected
                    text: "dcal is not running"
                    color: Theme.on_surface
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
                GlyphButton {
                    glyph: root.showDone ? 0xf0208 : 0xf0209
                    active: root.showDone
                    onClicked: root.showDone = !root.showDone
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Field {
                    id: addField
                    glyph: 0xf0415
                    placeholder: "Add to " + root.newTaskList
                    onAccepted: {
                        if (root.add(text))
                            text = "";
                    }
                    onCancelled: {
                        text = "";
                        root.addError = "";
                        input.focus = false;
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: -4
                visible: root.addError !== "" || addField.input.activeFocus
                text: root.addError || "Enter adds it  ·  @tomorrow, @fri or @3.10. sets a due date"
                wrapMode: Text.Wrap
                color: root.addError ? Theme.error : Theme.on_surface_variant
                font.family: Theme.uiFont
                font.pixelSize: 11
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 4
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: root.rows
                delegate: TaskRow {}

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    visible: list.count === 0 && Dcal.connected
                    text: "Nothing to do"
                    color: Theme.on_surface_variant
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
            }
        }
    }

    // A task like the calendar's event blocks: circle, title and due date. Clicked, it turns into
    // the editor, styled like the calendar's appointment editor.
    component TaskRow: Rectangle {
        id: row

        required property var modelData
        readonly property var task: modelData.task
        readonly property bool open: root.expanded === task.id
        readonly property bool done: root.isDone(task)
        readonly property color accent: root.accent(task.calendarId)
        readonly property real due: root.dueIn(task)
        readonly property string notes: (task.description ?? "").trim()

        x: modelData.depth * 20
        width: ListView.view.width - x
        height: open ? (editor.item?.implicitHeight ?? 0) + 24 : Math.max(32, info.implicitHeight + 14)
        radius: open ? 12 : 6
        color: open ? Theme.surface : Qt.alpha(Qt.tint(Theme.surface_container, Qt.alpha(accent, mouse.containsMouse ? 0.38 : 0.26)), 0.7)
        border.width: open ? 2 : 1
        border.color: open ? Theme.primary : Qt.alpha(accent, 0.45)
        opacity: done && !open ? 0.65 : 1
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.open ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: root.expanded = row.task.id
        }

        Rectangle {
            x: 8
            y: 7
            width: 18
            height: 18
            radius: 9
            visible: !row.open
            color: row.done ? row.accent : checkMouse.containsMouse ? Qt.alpha(row.accent, 0.25) : "transparent"
            border.width: 2
            border.color: row.accent

            Text {
                anchors.centerIn: parent
                visible: row.done
                text: Theme.g(0xf012c)
                color: Theme.surface
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
            }
            MouseArea {
                id: checkMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDone(row.task)
            }
        }

        Column {
            id: info

            x: 34
            y: 7
            width: row.width - 42
            visible: !row.open
            spacing: 1

            Text {
                width: parent.width
                text: row.task.summary
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: row.accent
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                font.strikeout: row.done
            }
            Detail {
                visible: text !== ""
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                color: row.due < 0 && !row.done ? Theme.error : Theme.on_surface_variant
                text: {
                    const parts = [];
                    if (!isNaN(row.due))
                        parts.push(Theme.g(0xf073) + "  " + root.dueLabel(row.task));
                    if (row.notes !== "")
                        parts.push(Theme.g(0xf036) + "  " + row.notes.split("\n")[0]);
                    return parts.join("    ");
                }
            }
        }

        Loader {
            id: editor
            x: 12
            y: 12
            width: row.width - 24
            active: row.open
            sourceComponent: Editor {
                task: row.task
            }
        }
    }

    // Enter (Ctrl+Enter in the notes) saves, Escape cancels.
    component Editor: ColumnLayout {
        id: editor

        property var task
        property bool saving: false
        property bool confirmDelete: false
        property string error: ""

        function save() {
            const summary = titleField.text.trim();
            const due = root.parseDue(dueField.text);
            if (summary === "")
                error = "Add a title";
            else if (due === undefined)
                error = "Write dates like 3.10., tomorrow or fri";
            else
                error = "";
            if (error !== "" || saving)
                return;

            const params = {
                id: task.id,
                summary: summary,
                description: notes.text.trim()
            };
            if (due) {
                params.due = due.toISOString();
                params.allDay = true;
            } else if (task.due) {
                params.due = ""; // clears it
            }
            run("tasks.update", params);
        }
        function remove() {
            if (!confirmDelete) {
                confirmDelete = true;
                return;
            }
            run("tasks.delete", {
                id: task.id
            });
        }
        function run(method, params) {
            if (saving)
                return;
            saving = true;
            const sent = Dcal.request(method, params, () => {
                root.close();
                root.load();
            }, message => {
                editor.saving = false;
                editor.error = message;
            });
            if (!sent) {
                saving = false;
                error = "dcal is not running";
            }
        }

        Component.onCompleted: titleField.input.forceActiveFocus()

        spacing: 8

        SectionLabel {
            text: "Edit task"
            hint: root.listName(editor.task.calendarId)
        }
        Field {
            id: titleField
            placeholder: "Title"
            text: editor.task.summary
            onAccepted: editor.save()
            onCancelled: root.close()
        }
        Field {
            id: dueField
            glyph: 0xf073
            placeholder: "Due: 3.10., tomorrow, fri or +3"
            text: root.dueText(editor.task)
            onAccepted: editor.save()
            onCancelled: root.close()
        }
        // Multi-line, so it's not a Field; styled like one.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(30, notes.implicitHeight + 14)
            radius: 8
            color: Theme.surface_container_high
            border.width: 1
            border.color: notes.activeFocus ? Theme.primary : "transparent"

            Text {
                x: 10
                y: 7
                text: Theme.g(0xf036)
                color: Theme.on_surface_variant
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            TextEdit {
                id: notes

                x: 28
                y: 7
                width: parent.width - 36
                text: editor.task.description ?? ""
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                activeFocusOnTab: true
                color: Theme.on_surface
                selectionColor: Theme.primary
                selectedTextColor: Theme.on_primary
                font.family: Theme.uiFont
                font.pixelSize: 12
                Keys.onEscapePressed: root.close()
                Keys.onReturnPressed: event => {
                    if (event.modifiers & Qt.ControlModifier)
                        editor.save();
                    else
                        event.accepted = false;
                }

                Text {
                    anchors.fill: parent
                    visible: notes.text === ""
                    text: "Notes"
                    color: Theme.outline
                    font: notes.font
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: editor.error !== "" || editor.confirmDelete
            text: editor.error || "Click the bin again to delete the task"
            wrapMode: Text.Wrap
            color: Theme.error
            font.family: Theme.uiFont
            font.pixelSize: 11
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            GlyphButton {
                glyph: 0xf01b4
                size: 32
                fg: editor.confirmDelete ? Theme.error : Theme.on_surface_variant
                onClicked: editor.remove()
            }
            TextButton {
                text: "Cancel"
                onClicked: root.close()
            }
            Pill {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                text: editor.saving ? "Saving…" : "Save"
                active: true
                onClicked: editor.save()
            }
        }
    }

    component Detail: Text {
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.on_surface_variant
        font.family: Theme.uiFont
        font.pixelSize: 11
    }
}
