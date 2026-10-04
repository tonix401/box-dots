import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Below the clock block: a month calendar with ISO week numbers.
// Arrows or the mouse wheel change the month; clicking the month name goes back to today.
Popout {
    id: root

    alignRight: true
    contentWidth: 290

    readonly property date now: clock.date
    property int year: now.getFullYear()
    property int month: now.getMonth()

    function showToday() {
        year = now.getFullYear();
        month = now.getMonth();
    }
    function step(delta) {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    // 6 weeks starting on the Monday on or before the 1st.
    readonly property var weeks: {
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - (first.getDay() + 6) % 7);
        const out = [];
        for (let w = 0; w < 6; w++) {
            const days = [];
            for (let i = 0; i < 7; i++)
                days.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7 + i));
            out.push(days);
        }
        return out;
    }

    onOpenChanged: if (!open)
        showToday()

    SystemClock {
        id: clock
        precision: root.open ? SystemClock.Seconds : SystemClock.Minutes
    }

    // The bar shows the time; the header adds seconds and the full date.
    header: Item {
        BarText {
            height: parent.height
            text: Theme.g(0xf017) + " " + Qt.formatTime(root.now, "HH:mm:ss")
            color: Theme.on_surface
        }
        BarText {
            anchors.right: parent.right
            height: parent.height
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            color: Theme.on_surface
        }
    }

    Column {
        width: parent.width
        spacing: 10

        RowLayout {
            width: parent.width

            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                color: Theme.primary
                font.family: Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.Medium

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showToday()
                }
            }
            GlyphButton {
                glyph: 0xf0141
                onClicked: root.step(-1)
            }
            GlyphButton {
                glyph: 0xf0142
                onClicked: root.step(1)
            }
        }

        Grid {
            id: grid

            readonly property real cell: width / 8

            width: parent.width
            columns: 8

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse
                onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
            }

            Repeater {
                model: ["Wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Cell {
                    required property string modelData
                    required property int index
                    text: modelData
                    color: index === 0 ? Theme.outline : index >= 6 ? Theme.primary : Theme.on_surface_variant
                    font.pixelSize: 11
                }
            }

            Repeater {
                model: 48

                Item {
                    id: day

                    required property int index
                    readonly property int column: index % 8
                    readonly property date date: root.weeks[Math.floor(index / 8)][Math.max(0, column - 1)]
                    readonly property bool today: column > 0 && root.sameDay(date, root.now)

                    width: grid.cell
                    height: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: Theme.primary
                        visible: day.today
                    }

                    Cell {
                        anchors.fill: parent
                        text: day.column === 0 ? root.isoWeek(day.date) : day.date.getDate()
                        font.pixelSize: day.column === 0 ? 11 : 13
                        font.weight: day.today ? Font.Bold : Font.Normal
                        color: day.today ? Theme.on_primary : day.column === 0 ? Theme.outline : day.date.getMonth() !== root.month ? Qt.alpha(Theme.on_surface, 0.35) : Theme.on_surface
                    }
                }
            }
        }
    }

    component Cell: Text {
        width: grid.cell
        height: 22
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.uiFont
    }
}
