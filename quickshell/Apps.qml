pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Installed apps, ordered like rofi drun (launch counts from ~/.cache/rofi3.druncache, shared with rofi).
Singleton {
    id: root

    property var history: ({}) // desktop id -> launch count
    property var historyOrder: [] // desktop ids in file order; kept for equal counts

    // Most launched first, then everything else by name. Worked out in the background, not as a binding:
    // DesktopEntries fills in over many steps after it's first read, and a binding re-sorted (and the
    // launcher rebuilt its tiles) on every one. shell.qml reads this once after startup so it's ready.
    property var sorted: []
    readonly property var mostUsed: sorted.filter(e => (history[key(e)] ?? 0) > 0)

    function key(entry) {
        return entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop";
    }

    function resort() {
        const rankOf = {};
        historyOrder.forEach((k, i) => rankOf[k] = i);
        sorted = DesktopEntries.applications.values.map(e => {
            const k = key(e);
            return {
                entry: e,
                count: history[k] ?? 0,
                rank: rankOf[k] ?? -1,
                name: e.name.toLowerCase()
            };
        }).sort((a, b) => b.count - a.count || (a.rank < 0) - (b.rank < 0) || a.rank - b.rank || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0)).map(it => it.entry);
    }

    Timer {
        id: resortLater
        interval: 50
        onTriggered: root.resort()
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            resortLater.restart();
        }
    }
    onHistoryChanged: resortLater.restart()
    Component.onCompleted: resort()

    // Through uwsm so each app gets its own systemd scope instead of living in qs's
    // (see ~/.config/hypr/exec.lua). uwsm reads the desktop file itself: Exec, field codes, Path.
    function launch(entry) {
        count(entry);
        Quickshell.execDetached(["uwsm", "app", "--", key(entry)]);
    }

    // A desktop action ("New window", "Stop", ...) counts as a launch of its app.
    function launchAction(entry, action) {
        count(entry);
        Quickshell.execDetached(["uwsm", "app", "--", key(entry) + ":" + action.id]);
    }

    function count(entry) {
        const k = key(entry);
        const counts = Object.assign({}, history);
        counts[k] = (counts[k] ?? 0) + 1;
        const keys = historyOrder.includes(k) ? historyOrder : historyOrder.concat([k]);
        druncache.setText(keys.slice().sort((a, b) => counts[b] - counts[a]).map(id => `${counts[id]} ${id}`).join("\n") + "\n");
    }

    FileView {
        id: druncache
        path: Quickshell.env("HOME") + "/.cache/rofi3.druncache"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const counts = {}, order = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^(\d+) (.+)$/);
                if (m) {
                    counts[m[2]] = Number(m[1]);
                    order.push(m[2]);
                }
            }
            root.historyOrder = order;
            root.history = counts;
        }
    }
}
