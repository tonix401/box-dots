pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Installed apps, ordered like rofi drun (launch counts from ~/.cache/rofi3.druncache, shared with rofi),
// plus the start menu's pinned apps.
Singleton {
    id: root

    property var history: ({}) // desktop id -> launch count
    property var historyOrder: [] // desktop ids in file order; kept for equal counts
    property var pinned: [] // desktop ids

    function key(entry) {
        return entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop";
    }

    // Most launched first, then everything else by name.
    readonly property var sorted: DesktopEntries.applications.values.map(e => ({
                entry: e,
                count: history[key(e)] ?? 0,
                rank: historyOrder.indexOf(key(e))
            })).sort((a, b) => b.count - a.count || (a.rank < 0) - (b.rank < 0) || a.rank - b.rank || a.entry.name.localeCompare(b.entry.name, undefined, {
                sensitivity: "base"
            })).map(it => it.entry)

    readonly property var pinnedEntries: pinned.map(id => DesktopEntries.applications.values.find(e => key(e) === id)).filter(e => e)
    readonly property var mostUsed: sorted.filter(e => (history[key(e)] ?? 0) > 0 && !pinned.includes(key(e)))

    function launch(entry) {
        const k = key(entry);
        const counts = Object.assign({}, history);
        counts[k] = (counts[k] ?? 0) + 1;
        const keys = historyOrder.includes(k) ? historyOrder : historyOrder.concat([k]);
        druncache.setText(keys.slice().sort((a, b) => counts[b] - counts[a]).map(id => `${counts[id]} ${id}`).join("\n") + "\n");
        entry.execute();
    }

    function isPinned(entry) {
        return pinned.includes(key(entry));
    }

    function togglePin(entry) {
        const k = key(entry);
        pinned = isPinned(entry) ? pinned.filter(id => id !== k) : pinned.concat([k]);
        pins.setText(JSON.stringify(pinned, null, 2) + "\n");
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

    FileView {
        id: pins
        path: Quickshell.statePath("pinned-apps.json")
        printErrors: false
        onLoaded: {
            try {
                root.pinned = JSON.parse(text());
            } catch (e) {
                root.pinned = [];
            }
        }
    }
}
