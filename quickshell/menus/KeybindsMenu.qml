import QtQuick
import Quickshell.Io
import qs

// Keybind reference (SUPER+K), read-only: nothing runs on accept.
Menu {
    id: root

    readonly property var modifiers: [[64, "SUPER"], [4, "CTRL"], [1, "SHIFT"], [8, "ALT"]]
    readonly property var keyNames: ({
            "return": "Return",
            "space": "Space",
            "escape": "Escape",
            "period": ".",
            "backspace": "Backspace",
            "tab": "Tab",
            "left": "Left",
            "right": "Right",
            "up": "Up",
            "down": "Down"
        })

    function combo(bind) {
        const mods = modifiers.filter(m => bind.modmask & m[0]).map(m => m[1]);
        return mods.concat([keyNames[bind.key.toLowerCase()] ?? bind.key]).join(" + ");
    }

    // "Go to workspace 1..9" -> one "Go to workspace [1-9]" row, as in the python script.
    function collapseNumbered(entries) {
        const groups = {}, singles = [], order = [];
        for (const [desc, keys] of entries) {
            const dm = desc.match(/^(.+)\s+(\d)$/), cm = keys.match(/^(.+ \+) (\d)$/);
            if (dm && cm && dm[2] === cm[2]) {
                const key = dm[1] + "\u0000" + cm[1];
                if (!(key in groups)) {
                    groups[key] = [];
                    order.push(["group", key]);
                }
                groups[key].push(Number(dm[2]));
            } else {
                order.push(["single", singles.length]);
                singles.push([desc, keys]);
            }
        }
        const out = [];
        for (const [kind, key] of order) {
            if (kind === "single") {
                out.push(singles[key]);
                continue;
            }
            const digits = groups[key].slice().sort((a, b) => a - b);
            const [descPrefix, comboPrefix] = key.split("\u0000");
            const contiguous = digits.every((d, i) => d === digits[0] + i);
            if (digits.length > 1 && contiguous) {
                const r = `[${digits[0]}-${digits[digits.length - 1]}]`;
                out.push([`${descPrefix} ${r}`, `${comboPrefix} ${r}`]);
            } else {
                for (const d of digits)
                    out.push([`${descPrefix} ${d}`, `${comboPrefix} ${d}`]);
            }
        }
        return out;
    }

    boxWidth: 780
    placeholder: "Search keybinds..."
    matching: "fuzzy"
    lines: 14
    rowPadV: 10
    rowPadH: 16
    scrollbar: true
    highlightSelected: false // a reference list, nothing to select

    fontFamily: Theme.monoFont // descriptions are padded with spaces so the keys line up
    rowContent: MenuText {}

    Process {
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const binds = JSON.parse(text).filter(b => b.has_description && !b.mouse && !b.key.includes("mouse:"));
                const entries = root.collapseNumbered(binds.map(b => [b.description, root.combo(b)]));
                const pad = Math.max(...entries.map(e => Array.from(e[0]).length)) + 4;
                root.items = entries.map(([desc, keys]) => ({
                            text: desc + " ".repeat(pad - Array.from(desc).length) + keys
                        }));
            }
        }
    }
}
