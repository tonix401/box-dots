import QtQuick
import Quickshell
import Quickshell.Io
import qs

// hypr/scripts/rofi/clipboard-history-menu.py + rofi/clipboard.rasi
Menu {
    id: root

    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/cliphist-thumbs"
    readonly property string helpers: Quickshell.env("HOME") + "/.config/hypr/scripts/helpers"

    readonly property var ansi16: ["#000000", "#aa0000", "#00aa00", "#aaaa00", "#0000aa", "#aa00aa", "#00aaaa", "#aaaaaa", "#555555", "#ff5555", "#55ff55", "#ffff55", "#5555ff", "#ff55ff", "#55ffff", "#ffffff"]

    function hex2(n) {
        return n.toString(16).padStart(2, "0");
    }

    function color256(n) {
        if (n < 16)
            return ansi16[n];
        if (n < 232) {
            n -= 16;
            const c = x => x === 0 ? 0 : 55 + x * 40;
            return "#" + hex2(c(Math.floor(n / 36))) + hex2(c(Math.floor(n / 6) % 6)) + hex2(c(n % 6));
        }
        const v = 8 + (n - 232) * 10;
        return "#" + hex2(v) + hex2(v) + hex2(v);
    }

    function ansiColor(params) {
        const p = params ? params.split(";").map(x => Number(x) || 0) : [0];
        for (let i = 0; i < p.length; i++) {
            if (p[i] >= 30 && p[i] <= 37)
                return ansi16[p[i] - 30];
            if (p[i] >= 90 && p[i] <= 97)
                return ansi16[p[i] - 82];
            if (p[i] === 38 && p[i + 1] === 5 && i + 2 < p.length)
                return color256(p[i + 2]);
            if (p[i] === 38 && p[i + 1] === 2 && i + 4 < p.length)
                return "#" + hex2(p[i + 2]) + hex2(p[i + 3]) + hex2(p[i + 4]);
        }
        return null;
    }

    // Port of helpers/format-clipboard.py (hex codes and ANSI escapes shown in their own color),
    // plus tab expansion to 8 columns like pango does.
    function format(line) {
        const tab = line.indexOf("\t");
        if (tab >= 0)
            line = line.slice(0, tab) + " ".repeat(8 - tab % 8) + line.slice(tab + 1);
        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return esc(line).replace(/(#[0-9a-fA-F]{6})/g, '<font color="$1">$1</font>').replace(/(?:\x1b|\\e|\\033|\\x1b)\[([0-9;]*)m/g, (m, params) => {
            const c = ansiColor(params);
            return c ? `<font color="${c}">${m}</font>` : m;
        });
    }

    boxWidth: 620
    placeholder: "Search clipboard..."
    lines: 12
    rowPadV: 6
    rowContentHeight: 28
    scrollbar: true

    onAccepted: it => Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", it.text])

    rowContent: Row {
        id: row

        property var entry: parent.entry
        property bool selected: parent.selected
        property real fontPt: parent.fontPt

        height: parent.height

        // thumbnail slot; the space is kept even without a thumbnail so the ids line up
        Item {
            width: 28 + 14
            height: parent.height

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                visible: row.entry.thumb !== ""
                source: row.entry.thumb
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: row.parent.width - 42
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: row.entry.markup
            color: row.selected ? Theme.on_primary : Theme.primary
            font.family: Theme.fontFamily
            font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
            font.pointSize: row.fontPt
            renderType: Text.NativeRendering
        }
    }

    // Same as the script: list, generate thumbnails for images, then show.
    Process {
        running: true
        command: ["sh", "-c", `l=$(cliphist list) || exit 1; mkdir -p "$1"; printf '%s\\n' "$l" | python3 "$2/generate-thumbs.py" "$1"; printf '%s\\n' "$l"`, "sh", root.thumbDir, root.helpers]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l !== "").map(line => {
                    const tab = line.indexOf("\t");
                    const binary = line.slice(tab + 1).includes("[[ binary data");
                    return {
                        text: line,
                        markup: root.format(line),
                        thumb: binary && tab > 0 ? `file://${root.thumbDir}/${line.slice(0, tab)}.png` : ""
                    };
                });
            }
        }
    }
}
