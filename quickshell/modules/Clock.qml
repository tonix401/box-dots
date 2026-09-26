import QtQuick
import Quickshell
import qs
import qs.components

Module {
    id: root

    property bool alt: false

    // waybar's {calendar}: month grid, weeks starting Monday, today highlighted.
    function calendar(now) {
        const nb = s => s.replace(/ /g, "&nbsp;");
        const first = new Date(now.getFullYear(), now.getMonth(), 1);
        const days = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        const title = Qt.formatDate(now, "MMMM yyyy");
        const pad = Math.floor((20 - title.length) / 2);
        const lines = [`<b>${nb(" ".repeat(Math.max(0, pad)) + title)}</b>`, nb("Mo Tu We Th Fr Sa Su")];
        const cells = Array((first.getDay() + 6) % 7).fill(nb("  "));
        for (let d = 1; d <= days; d++) {
            const s = nb(String(d).padStart(2, " "));
            cells.push(d === now.getDate() ? `<b><u><font color="${Theme.primary}">${s}</font></u></b>` : s);
        }
        for (let i = 0; i < cells.length; i += 7)
            lines.push(cells.slice(i, i + 7).join("&nbsp;"));
        return lines.join("<br>");
    }

    text: alt ? Theme.g(0xf00f1) + " " + Qt.formatDate(clock.date, "yyyy/MM/dd") : Theme.g(0xf017) + " " + Qt.formatTime(clock.date, "HH:mm")
    tooltip: hovered ? calendar(clock.date) : ""
    tooltipFormat: Text.StyledText
    onClicked: alt = !alt

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
