import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// This week's dcal events from 7:00 to 22:00, on the desktop below all windows.
// Arrows or the mouse wheel change the week; clicking the title (or a minute without the
// pointer on it) goes back to this week. Clicking an event grows its block to show everything
// about it; clicking it again or anywhere else in the grid shrinks it back. Clicking an empty
// slot (or dragging over a time range) opens an editor for a new appointment.
PanelWindow {
    id: root

    readonly property int firstHour: 7
    readonly property int lastHour: 22
    readonly property int hourHeight: 52
    readonly property int gutter: 48 // hour labels
    readonly property int pad: 8

    property int weekOffset: 0
    property string expanded: "" // key of the block showing its details
    property var draft: null // {day, s, e} (minutes after firstHour) of the appointment being added
    property string lastCalendar: "" // where the last new appointment went
    // Calendars that take new events: not read-only, not task lists.
    readonly property var writable: Dcal.calendars.filter(c => !c.readOnly && !c.hidden && (c.supportedComponents?.includes("VEVENT") ?? true))
    readonly property date now: clock.date
    // Changes once a day, so the week (and the events request) doesn't follow every minute tick.
    readonly property string today: Qt.formatDate(now, "yyyy-MM-dd")
    readonly property date weekStart: {
        const t = parseDay(today);
        const d = new Date(t.getFullYear(), t.getMonth(), t.getDate() + 7 * weekOffset);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() - (d.getDay() + 6) % 7);
    }
    readonly property var days: [0, 1, 2, 3, 4, 5, 6].map(i => new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + i))
    readonly property int todayColumn: dayIndex(today)

    property var events: []
    readonly property var timed: layoutTimed(events, days)
    readonly property var allDay: layoutAllDay(events, weekStart)
    readonly property int allDayLanes: allDay.reduce((n, x) => Math.max(n, x.lane + 1), 0)

    readonly property var accents: [Theme.primary, Theme.tertiary, Theme.secondary]

    function parseDay(s) {
        const [y, m, d] = s.slice(0, 10).split("-").map(Number);
        return new Date(y, m - 1, d);
    }
    // Days from the week's Monday; all-day events carry their date as UTC midnight.
    function dayIndex(s) {
        return Math.round((parseDay(s) - weekStart) / 86400000);
    }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    function accent(calendarId) {
        const i = Dcal.calendars.findIndex(c => c.id === calendarId);
        return accents[Math.max(0, i) % accents.length];
    }

    function load() {
        const from = weekStart;
        const to = new Date(from.getFullYear(), from.getMonth(), from.getDate() + 7);
        Dcal.request("events.list", {
            from: from.toISOString(),
            to: to.toISOString(),
            limit: 1000
        }, result => {
            if (from.getTime() !== root.weekStart.getTime())
                return; // an older week answered late
            const hidden = Dcal.calendars.filter(c => c.hidden).map(c => c.id);
            // Habit check-ins have their own widget.
            root.events = (result?.events ?? []).filter(ev => !hidden.includes(ev.calendarId) && ev.calendarId !== Dcal.habitsCalendarId);
        });
    }

    // Timed events cut to each day's visible hours (s/e in minutes after firstHour). Overlapping
    // events split the day's width: each cluster of overlaps gets as many columns as it needs.
    function layoutTimed(events, days) {
        const out = [];
        days.forEach((day, i) => {
            const lo = new Date(day.getFullYear(), day.getMonth(), day.getDate(), firstHour);
            const hi = new Date(day.getFullYear(), day.getMonth(), day.getDate(), lastHour);
            const segs = [];
            for (const ev of events) {
                if (ev.allDay)
                    continue;
                const start = new Date(ev.start);
                const end = Math.max(new Date(ev.end), start.getTime() + 15 * 60000);
                const s = Math.max(start, lo), e = Math.min(end, hi);
                if (e > s)
                    segs.push({
                        ev: ev,
                        day: i,
                        s: (s - lo) / 60000,
                        e: (e - lo) / 60000
                    });
            }
            segs.sort((a, b) => a.s - b.s || b.e - a.e);

            let cluster = [], ends = [], clusterEnd = 0;
            const flush = () => {
                cluster.forEach(x => x.cols = ends.length);
                cluster = [];
                ends = [];
            };
            for (const x of segs) {
                if (x.s >= clusterEnd)
                    flush();
                let col = ends.findIndex(end => end <= x.s);
                if (col < 0)
                    col = ends.push(x.e) - 1;
                else
                    ends[col] = x.e;
                x.col = col;
                cluster.push(x);
                clusterEnd = Math.max(clusterEnd, x.e);
                out.push(x);
            }
            flush();
        });
        return out;
    }

    // All-day events as bars over the days they cover (end exclusive), stacked into lanes.
    function layoutAllDay(events, weekStart) {
        const items = events.filter(ev => ev.allDay).map(ev => {
            const s = dayIndex(ev.start);
            return {
                ev: ev,
                from: Math.max(0, s),
                to: Math.min(7, Math.max(s + 1, dayIndex(ev.end)))
            };
        }).filter(x => x.to > x.from).sort((a, b) => a.from - b.from || b.to - a.to);
        const lanes = [];
        for (const x of items) {
            let lane = lanes.findIndex(end => end <= x.from);
            if (lane < 0)
                lane = lanes.push(x.to) - 1;
            else
                lanes[lane] = x.to;
            x.lane = lane;
        }
        return items;
    }

    function toggle(key) {
        expanded = expanded === key ? "" : key;
    }
    function calendarName(id) {
        return Dcal.calendars.find(c => c.id === id)?.name ?? "";
    }
    function when(ev) {
        const date = d => Qt.formatDate(d, "ddd d MMM");
        if (ev.allDay) {
            const s = parseDay(ev.start), e = parseDay(ev.end);
            e.setDate(e.getDate() - 1); // end is exclusive
            return e > s ? date(s) + " – " + date(e) : date(s);
        }
        const s = new Date(ev.start), e = new Date(ev.end);
        const time = d => Qt.formatTime(d, "HH:mm");
        if (s.toDateString() === e.toDateString())
            return date(s) + ", " + time(s) + "–" + time(e);
        return date(s) + " " + time(s) + " – " + date(e) + " " + time(e);
    }
    // Descriptions come as plain text or (from Google) HTML; iCal feeds pad them with blank lines.
    function description(ev) {
        return (ev.description ?? "").replace(/\n\s*\n\s*(\n\s*)+/g, "\n\n").trim();
    }

    function clock(minutes) {
        const m = firstHour * 60 + minutes;
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    onWeekStartChanged: {
        expanded = "";
        draft = null;
        load();
    }
    Component.onCompleted: load()

    Connections {
        target: Dcal
        function onRevisionChanged() {
            root.load();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 60000
        running: (root.weekOffset !== 0 || root.expanded !== "") && root.draft === null && !hover.hovered
        onTriggered: {
            root.weekOffset = 0;
            root.expanded = "";
        }
    }

    // Placed by shell.qml (top left, under the bar), which sets `room`: how far the window (and the
    // dark backdrop) reaches past each edge of the panel, the last `fade` px on the right fading out.
    property var room: ({
            left: 0,
            top: 0,
            right: 0,
            bottom: 0
        })
    property int fade: 0
    readonly property int panelWidth: 1320
    readonly property int panelHeight: panel.height

    implicitWidth: room.left + panelWidth + room.right
    implicitHeight: room.top + content.implicitHeight + 2 * pad + room.bottom
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-calendar"
    // Takes the keyboard on click only while the pointer is on it (so the click that opens the editor
    // focuses it), and keeps it while an appointment is being added.
    WlrLayershell.keyboardFocus: draft !== null || hover.hovered ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Backdrop {
        fade: root.fade
    }

    Item {
        id: panel

        x: root.room.left
        y: root.room.top
        width: root.panelWidth
        height: content.implicitHeight + 2 * root.pad

        HoverHandler {
            id: hover
        }

        ColumnLayout {
            id: content

            x: root.pad
            y: root.pad
            width: parent.width - 2 * root.pad
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: {
                        const a = root.days[0], b = root.days[6];
                        if (a.getMonth() === b.getMonth())
                            return Qt.formatDate(a, "MMMM yyyy");
                        return Qt.formatDate(a, a.getFullYear() === b.getFullYear() ? "MMMM" : "MMMM yyyy") + " – " + Qt.formatDate(b, "MMMM yyyy");
                    }
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
                    text: "Week " + root.isoWeek(root.days[0])
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
                // Syncs all calendars (and task lists) with their servers; spins until they report back.
                GlyphButton {
                    id: syncButton
                    glyph: 0xf0450
                    enabled: Dcal.connected
                    onClicked: Dcal.sync()

                    RotationAnimator on rotation {
                        running: Dcal.syncing
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                        onRunningChanged: if (!running)
                            syncButton.rotation = 0
                    }
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

            // Day names
            Row {
                Layout.leftMargin: root.gutter
                Layout.fillWidth: true

                Repeater {
                    model: root.days

                    Item {
                        id: dayHead

                        required property date modelData
                        required property int index
                        readonly property bool isToday: index === root.todayColumn

                        width: card.width / 7
                        height: 30

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDate(dayHead.modelData, "ddd")
                                color: dayHead.index >= 5 ? Theme.primary : Theme.on_surface
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: dayHead.isToday ? Theme.primary : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: dayHead.modelData.getDate()
                                    color: dayHead.isToday ? Theme.on_primary : Theme.on_surface
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: dayHead.isToday ? Font.Bold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }

            // All-day events (above the grid, so an open chip can grow over it)
            Item {
                z: 1
                Layout.leftMargin: root.gutter
                Layout.fillWidth: true
                Layout.preferredHeight: root.allDayLanes * 24 - 2
                visible: root.allDayLanes > 0

                Repeater {
                    model: root.allDay

                    Block {
                        required property var modelData

                        ev: modelData.ev
                        baseX: modelData.from * card.width / 7 + 3
                        baseY: modelData.lane * 24
                        baseWidth: (modelData.to - modelData.from) * card.width / 7 - 6
                        baseHeight: 22
                        maxRight: card.width - 3
                    }
                }
            }

            // Hours
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: (root.lastHour - root.firstHour) * root.hourHeight
                Layout.topMargin: 4

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: event => root.weekOffset += event.angleDelta.y > 0 ? -1 : 1
                }

                Repeater {
                    model: root.lastHour - root.firstHour + 1

                    Text {
                        required property int index
                        width: root.gutter - 10
                        y: index * root.hourHeight - height / 2
                        horizontalAlignment: Text.AlignRight
                        text: String(root.firstHour + index).padStart(2, "0") + ":00"
                        color: Theme.on_surface
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    id: card

                    x: root.gutter
                    width: parent.width - root.gutter
                    height: parent.height
                    radius: 12
                    color: "transparent"

                    Rectangle {
                        visible: root.todayColumn >= 0 && root.todayColumn < 7
                        x: root.todayColumn * card.width / 7
                        width: card.width / 7
                        height: parent.height
                        radius: 12
                        color: Qt.alpha(Theme.primary, 0.06)
                    }

                    Repeater {
                        model: root.lastHour - root.firstHour - 1

                        Rectangle {
                            required property int index
                            y: (index + 1) * root.hourHeight
                            width: card.width
                            height: 1
                            color: Qt.alpha(Theme.outline_variant, 0.5)
                        }
                    }

                    Repeater {
                        model: 6

                        Rectangle {
                            required property int index
                            x: Math.round((index + 1) * card.width / 7)
                            width: 1
                            height: card.height
                            color: Qt.alpha(Theme.outline_variant, 0.5)
                        }
                    }

                    // Empty grid: a click closes an open block or editor; otherwise a click picks the
                    // hour under it, a drag a range in 15-minute steps, for a new appointment.
                    MouseArea {
                        id: slots

                        readonly property int total: (root.lastHour - root.firstHour) * 60
                        property bool closing: false
                        property int day: 0
                        property real from: 0
                        property var range: null // {day, s, e} while dragging

                        function minuteAt(y) {
                            return Math.max(0, Math.min(total, y * 60 / root.hourHeight));
                        }

                        anchors.fill: parent
                        preventStealing: true
                        onPressed: mouse => {
                            closing = root.expanded !== "" || root.draft !== null;
                            root.expanded = "";
                            root.draft = null;
                            day = Math.max(0, Math.min(6, Math.floor(mouse.x / (width / 7))));
                            from = minuteAt(mouse.y);
                            range = null;
                        }
                        onPositionChanged: mouse => {
                            const m = minuteAt(mouse.y);
                            if (closing || (range === null && Math.abs(m - from) * root.hourHeight / 60 < 6))
                                return;
                            const a = Math.min(total - 15, Math.floor(from / 15) * 15);
                            range = m >= from ? {
                                day: day,
                                s: a,
                                e: Math.max(a + 15, Math.ceil(m / 15) * 15)
                            } : {
                                day: day,
                                s: Math.floor(m / 15) * 15,
                                e: a + 15
                            };
                        }
                        onReleased: {
                            if (closing)
                                return;
                            const s = Math.min(total - 60, Math.floor(from / 30) * 30);
                            root.draft = range ?? {
                                day: day,
                                s: s,
                                e: s + 60
                            };
                            range = null;
                        }
                    }

                    Repeater {
                        model: root.timed

                        Block {
                            required property var modelData
                            readonly property real span: card.width / 7 - 6

                            ev: modelData.ev
                            baseX: modelData.day * card.width / 7 + 3 + modelData.col * span / modelData.cols
                            baseY: modelData.s * root.hourHeight / 60 + 1
                            baseWidth: span / modelData.cols - (modelData.cols > 1 ? 2 : 0)
                            baseHeight: Math.max(18, (modelData.e - modelData.s) * root.hourHeight / 60 - 2)
                            maxRight: card.width - 3
                            maxBottom: card.height - 1
                        }
                    }

                    // The slot being picked or added
                    Rectangle {
                        readonly property var r: slots.range ?? root.draft

                        visible: r !== null
                        x: (r?.day ?? 0) * card.width / 7 + 3
                        y: (r?.s ?? 0) * root.hourHeight / 60 + 1
                        width: card.width / 7 - 6
                        height: ((r?.e ?? 0) - (r?.s ?? 0)) * root.hourHeight / 60 - 2
                        z: 1
                        radius: 6
                        color: Qt.alpha(Theme.primary, 0.25)
                        border.width: 2
                        border.color: Theme.primary

                        Text {
                            x: 8
                            y: 5
                            text: root.clock(parent.r?.s ?? 0) + "–" + root.clock(parent.r?.e ?? 0)
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // Next to the slot: right of its day, or left of it on the last days.
                    Loader {
                        readonly property real slotX: (root.draft?.day ?? 0) * card.width / 7

                        active: root.draft !== null
                        z: 3
                        x: slotX + card.width / 7 + 300 <= card.width ? slotX + card.width / 7 + 4 : slotX - 304
                        y: Math.max(0, Math.min((root.draft?.s ?? 0) * root.hourHeight / 60, card.height - height))
                        sourceComponent: Editor {}
                    }

                    // Current time
                    Item {
                        readonly property real minutes: (root.now.getHours() - root.firstHour) * 60 + root.now.getMinutes()

                        visible: root.todayColumn >= 0 && root.todayColumn < 7 && minutes >= 0 && minutes <= (root.lastHour - root.firstHour) * 60
                        x: root.todayColumn * card.width / 7
                        y: minutes * root.hourHeight / 60 - 1
                        width: card.width / 7
                        height: 2

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.primary
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: -4
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.primary
                        }
                    }
                }
            }
        }
    }

    // An event: title (and time/place if it fits) at its base geometry; clicked, it grows to at
    // least 300px wide and as tall as its details, staying inside maxRight/maxBottom.
    component Block: Rectangle {
        id: block

        required property var ev
        property real baseX
        property real baseY
        property real baseWidth
        property real baseHeight
        property real maxRight: Infinity
        property real maxBottom: Infinity

        readonly property string key: ev.id + ev.start
        readonly property bool open: root.expanded === key
        readonly property color accent: root.accent(ev.calendarId)
        readonly property bool roomy: baseHeight >= 38
        readonly property string where: (ev.location ?? "").trim()
        readonly property string notes: root.description(ev)
        readonly property real targetWidth: open ? Math.max(baseWidth, 300) : baseWidth
        readonly property real targetHeight: open ? Math.max(baseHeight, info.implicitHeight + 12) : baseHeight

        x: open ? Math.max(0, Math.min(baseX, maxRight - targetWidth)) : baseX
        y: open ? Math.max(0, Math.min(baseY, maxBottom - targetHeight)) : baseY
        width: targetWidth
        height: targetHeight
        z: open || grow.running ? 2 : 0
        radius: 6
        color: Qt.alpha(Qt.tint(Theme.surface_container, Qt.alpha(accent, mouse.containsMouse ? 0.38 : 0.26)), open ? 0.95 : 0.7)
        border.width: 1
        border.color: Qt.alpha(accent, open ? 0.8 : 0.45)
        opacity: !open && new Date(ev.end) < root.now ? 0.65 : 1
        clip: true

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                id: grow
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle(block.key)
        }

        // Laid out at the target width right away, so the height to grow to is known up front.
        Column {
            id: info

            x: 8
            y: block.roomy || block.open ? 5 : (block.baseHeight - title.height) / 2
            width: block.targetWidth - 14
            spacing: block.open ? 4 : 1

            Text {
                id: title
                width: parent.width
                text: block.ev.summary
                wrapMode: Text.Wrap
                maximumLineCount: block.open ? 100 : Math.max(1, Math.floor((block.baseHeight - 10 - (block.roomy ? 15 : 0)) / 15))
                elide: Text.ElideRight
                color: block.accent
                font.family: Theme.fontFamily
                font.pixelSize: block.open ? 13 : 12
                font.weight: Font.Medium
                font.strikeout: block.ev.status === "cancelled"
            }
            Detail {
                visible: block.roomy && !block.open
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                text: {
                    const time = Qt.formatTime(new Date(block.ev.start), "HH:mm") + "–" + Qt.formatTime(new Date(block.ev.end), "HH:mm");
                    return block.where ? time + "  " + block.where : time;
                }
            }
            Detail {
                visible: block.open
                text: Theme.g(0xf017) + "  " + root.when(block.ev) + (block.ev.status === "confirmed" ? "" : "  (" + block.ev.status + ")")
            }
            Detail {
                visible: block.open && block.where !== ""
                text: Theme.g(0xf041) + "  " + block.where
            }
            Detail {
                visible: block.open
                text: Theme.g(0xf073) + "  " + root.calendarName(block.ev.calendarId)
            }
            Detail {
                visible: block.open && (block.ev.meetingUrl ?? "") !== ""
                text: Theme.g(0xf0c1) + "  " + block.ev.meetingUrl
                wrapMode: Text.WrapAnywhere
            }
            Detail {
                visible: block.open && block.notes !== ""
                topPadding: 4
                text: block.notes
                textFormat: /<[a-z][^>]*>/i.test(block.notes) ? Text.StyledText : Text.PlainText
                color: Theme.on_surface
                maximumLineCount: 16
                elide: Text.ElideRight
            }
        }
    }

    // Form for a new appointment in the `draft` slot. Enter saves, Escape cancels.
    component Editor: Rectangle {
        id: editor

        property bool allDay: false
        property bool saving: false
        property string error: ""
        property string calendarId: {
            const ids = root.writable.map(c => c.id);
            if (ids.includes(root.lastCalendar))
                return root.lastCalendar;
            // The account's main calendar is named after the account.
            return (root.writable.find(c => c.name === c.accountName) ?? root.writable[0])?.id ?? "";
        }
        readonly property date day: root.days[root.draft?.day ?? 0]

        function time(text) {
            const m = /^(\d{1,2}):?(\d{2})$/.exec(text.trim());
            if (!m || +m[1] > 23 || +m[2] > 59)
                return null;
            return new Date(day.getFullYear(), day.getMonth(), day.getDate(), +m[1], +m[2]);
        }

        function save() {
            const title = titleField.text.trim();
            let start, end;
            if (allDay) {
                start = new Date(Date.UTC(day.getFullYear(), day.getMonth(), day.getDate()));
                end = new Date(Date.UTC(day.getFullYear(), day.getMonth(), day.getDate() + 1));
            } else {
                start = time(fromField.text);
                end = time(toField.text);
            }
            if (title === "")
                error = "Add a title";
            else if (!start || !end)
                error = "Write times like 09:30";
            else if (end <= start)
                error = "The end has to be after the start";
            else if (calendarId === "")
                error = "No calendar takes new events";
            else
                error = "";
            if (error !== "" || saving)
                return;

            saving = true;
            const sent = Dcal.request("events.create", {
                calendarId: calendarId,
                summary: title,
                location: locationField.text.trim(),
                start: start.toISOString(),
                end: end.toISOString(),
                allDay: allDay
            }, () => {
                root.lastCalendar = editor.calendarId;
                root.draft = null;
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

        function cycleCalendar() {
            const i = root.writable.findIndex(c => c.id === calendarId);
            calendarId = root.writable[(i + 1) % root.writable.length]?.id ?? "";
        }

        Component.onCompleted: titleField.input.forceActiveFocus()

        width: 300
        height: form.implicitHeight + 24
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // keep clicks from reaching the grid below
        }

        ColumnLayout {
            id: form

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            SectionLabel {
                text: "New appointment"
                hint: Qt.formatDate(editor.day, "ddd d MMM")
            }
            Field {
                id: titleField
                placeholder: "Title"
                onAccepted: editor.save()
                onCancelled: root.draft = null
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Wide enough for any time: the fields' text margins plus "00:00".
                TextMetrics {
                    id: timeText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    text: "00:00"
                }
                Field {
                    id: fromField
                    Layout.fillWidth: false
                    Layout.preferredWidth: 28 + Math.ceil(timeText.advanceWidth) + 10
                    visible: !editor.allDay
                    glyph: 0xf017
                    text: root.clock(root.draft?.s ?? 0)
                    onAccepted: editor.save()
                    onCancelled: root.draft = null
                }
                Text {
                    visible: !editor.allDay
                    text: "–"
                    color: Theme.on_surface_variant
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                Field {
                    id: toField
                    Layout.fillWidth: false
                    Layout.preferredWidth: 10 + Math.ceil(timeText.advanceWidth) + 10
                    visible: !editor.allDay
                    text: root.clock(root.draft?.e ?? 0)
                    onAccepted: editor.save()
                    onCancelled: root.draft = null
                }
                Item {
                    Layout.fillWidth: true
                }
                Pill {
                    text: "All day"
                    active: editor.allDay
                    onClicked: editor.allDay = !editor.allDay
                }
            }
            Field {
                id: locationField
                glyph: 0xf041
                placeholder: "Location"
                onAccepted: editor.save()
                onCancelled: root.draft = null
            }
            Pill {
                Layout.fillWidth: true
                glyph: 0xf073
                text: (root.writable.find(c => c.id === editor.calendarId)?.name ?? "No calendar") + (root.writable.length > 1 ? "  " + Theme.g(0xf0e2) : "")
                dot: root.accent(editor.calendarId)
                onClicked: editor.cycleCalendar()
            }
            Text {
                Layout.fillWidth: true
                visible: editor.error !== ""
                text: editor.error
                wrapMode: Text.Wrap
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextButton {
                    text: "Cancel"
                    onClicked: root.draft = null
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
    }

    component Detail: Text {
        width: parent.width
        wrapMode: Text.Wrap
        color: Theme.on_surface_variant
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
