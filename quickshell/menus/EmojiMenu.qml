import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Emoji picker (SUPER+PERIOD): rofimoji's emoji data, copies the pick to the clipboard, neutral skin tone.
Menu {
    id: root

    readonly property string helper: Quickshell.shellDir + "/scripts/emoji.py"

    boxWidth: 540
    fontPt: 13
    placeholder: "Search emoji..."
    lines: 12
    rowPadV: 8
    matchText: it => [it.name, it.keywords]

    onAccepted: it => {
        Quickshell.execDetached(["wl-copy", it.char]);
        Quickshell.execDetached([helper, "pick", it.char]);
    }

    // the emoji in a fixed column, so the names line up with a clear gap
    rowContent: Row {
        id: row

        property var entry: parent.entry
        property bool selected: parent.selected
        property real fontPt: parent.fontPt

        width: parent.width
        height: parent.height
        spacing: 14

        Text {
            width: 26
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: row.entry.char
            font.pointSize: row.fontPt + 1
        }
        Text {
            width: parent.width - 26 - parent.spacing
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: row.entry.name // keywords stay searchable, just not shown
            color: row.selected ? Theme.on_primary : Theme.primary
            font.family: Theme.uiFont
            font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
            font.pointSize: row.fontPt
            renderType: Text.NativeRendering
        }
    }

    // rofimoji's description is "name <small>(keywords)</small>" with HTML entities ("Antigua &amp; Barbuda");
    // split and decode it once here, so rows render plain text and the search doesn't run regexes per item.
    function load(json) {
        const decode = t => t.includes("&") ? t.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&amp;/g, "&") : t;
        items = JSON.parse(json).map(([char, description]) => {
            const at = description.indexOf(" <small>("), end = description.lastIndexOf(")</small>");
            if (at < 0 || end < at)
                return {
                    char: char,
                    name: decode(description),
                    keywords: ""
                };
            return {
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
        onLoaded: root.load(text())
    }

    Process {
        running: true
        command: [root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: if (root.items.length === 0)
                root.load(text)
        }
    }
}
