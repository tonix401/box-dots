import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Symbol picker (SUPER+PERIOD): emoji, Nerd Font glyphs and Unicode characters in one search, grouped by
// the set they came from (the best-matching set first; CTRL+Up/Down jump between sets). Copies the pick.
Menu {
    id: root

    readonly property string emojiHelper: Quickshell.shellDir + "/scripts/emoji.py"
    readonly property string helpers: Quickshell.env("HOME") + "/.config/hypr/scripts/helpers/"

    // filled separately as each file loads, then joined in a fixed order (equal matches: emoji first)
    property var emoji: []
    property var nerdfont: []
    property var unicode: []
    items: emoji.concat(nerdfont, unicode)

    boxWidth: 620
    fontPt: 13
    placeholder: "Search emoji, nerd font icons, unicode..."
    lines: 14
    rowPadV: 8
    matchText: it => [it.name, it.keywords]
    groupOf: it => it.set

    onAccepted: it => {
        Quickshell.execDetached(["wl-copy", it.char]);
        if (it.set === "Emoji")
            Quickshell.execDetached([emojiHelper, "pick", it.char]);
    }

    // the symbol in a fixed column, then the name, the code point on the right
    rowContent: Row {
        id: row

        property var entry: parent.entry
        property bool selected: parent.selected
        property real fontPt: parent.fontPt
        readonly property color fg: selected ? Theme.on_primary : Theme.primary

        width: parent.width
        height: parent.height
        spacing: 14

        Text {
            width: 26
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: row.entry.shown ?? row.entry.char
            color: row.fg
            font.family: row.entry.set === "Emoji" ? Theme.uiFont : Theme.fontFamily
            font.pointSize: row.fontPt + (row.entry.set === "Emoji" ? 1 : 2)
        }
        Text {
            width: parent.width - 26 - 80 - 2 * parent.spacing
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: row.entry.name // keywords stay searchable, just not shown
            color: row.fg
            font.family: Theme.uiFont
            font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
            font.pointSize: row.fontPt
            renderType: Text.NativeRendering
        }
        Text {
            width: 80
            height: parent.height
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: "U+" + row.entry.char.codePointAt(0).toString(16).toUpperCase().padStart(4, "0")
            color: row.fg
            opacity: 0.6
            font.family: Theme.uiFont
            font.pointSize: row.fontPt - 2
        }
    }

    // ── Emoji: rofimoji's data via scripts/emoji.py ──
    // rofimoji's description is "name <small>(keywords)</small>" with HTML entities ("Antigua &amp; Barbuda");
    // split and decode it once here, so rows render plain text and the search doesn't run regexes per item.
    function loadEmoji(json) {
        const decode = t => t.includes("&") ? t.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&amp;/g, "&") : t;
        emoji = JSON.parse(json).map(([char, description]) => {
            const at = description.indexOf(" <small>("), end = description.lastIndexOf(")</small>");
            if (at < 0 || end < at)
                return {
                    set: "Emoji",
                    char: char,
                    name: decode(description),
                    keywords: ""
                };
            return {
                set: "Emoji",
                char: char,
                name: decode(description.slice(0, at) + description.slice(end + 9)), // a few have more after </small>
                keywords: decode(description.slice(at + 9, end))
            };
        });
    }

    // The list emoji.py wrote last time shows at once; the helper refreshes it in the background (and is
    // what fills the menu when there is no cache yet).
    FileView {
        path: Quickshell.env("HOME") + "/.cache/box-dots/emoji-list.json"
        blockLoading: true
        printErrors: false
        onLoaded: root.loadEmoji(text())
    }

    Process {
        running: true
        command: [root.emojiHelper, "list"]
        stdout: StdioCollector {
            onStreamFinished: if (root.emoji.length === 0)
                root.loadEmoji(text)
        }
    }

    // ── Nerd Font: nerdfont.txt, "<glyph> <name>" per line ──
    FileView {
        path: root.helpers + "nerdfont.txt"
        onLoaded: root.nerdfont = text().split("\n").filter(l => l !== "").map(l => {
            const space = l.indexOf(" ");
            return {
                set: "Nerd Font",
                char: l.slice(0, space),
                name: l.slice(space + 1),
                keywords: ""
            };
        })
    }

    // ── Unicode: unicode.txt (generate-unicode.py), "<hex>\t<name>" per line, searchable by U+code ──
    FileView {
        path: root.helpers + "unicode.txt"
        onLoaded: root.unicode = text().split("\n").filter(l => l !== "").map(l => {
            const tab = l.indexOf("\t");
            const cp = parseInt(l.slice(0, tab), 16);
            const char = String.fromCodePoint(cp);
            const name = l.slice(tab + 1);
            return {
                set: "Unicode",
                char: char,
                // combining marks on a dotted circle, controls as their name only
                shown: cp < 0x20 || (cp >= 0x7f && cp < 0xa0) ? "" : name.startsWith("combining ") ? "◌" + char : char,
                name: name,
                keywords: "u+" + l.slice(0, tab).toLowerCase()
            };
        })
    }
}
