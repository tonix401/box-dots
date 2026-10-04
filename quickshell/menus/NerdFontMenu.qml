import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Nerd Font glyph picker (SUPER+COMMA).
Menu {
    id: root

    boxWidth: 540
    fontPt: 13
    placeholder: "Search nerd font icons..."
    lines: 12
    rowPadV: 8

    onAccepted: it => Quickshell.execDetached(["wl-copy", it.text.split(/\s+/)[0]])

    // the glyph in a fixed column, so the names line up with a clear gap
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
            text: row.entry.glyph
            color: row.fg
            font.family: Theme.fontFamily
            font.pointSize: row.fontPt + 2
        }
        Text {
            width: parent.width - 26 - parent.spacing
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: row.entry.name
            color: row.fg
            font.family: Theme.uiFont
            font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
            font.pointSize: row.fontPt
            renderType: Text.NativeRendering
        }
    }

    // nerdfont.txt: "<glyph> <name>" per line; `text` stays the whole line, which is what the search matches
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/scripts/helpers/nerdfont.txt"
        onLoaded: root.items = text().split("\n").filter(l => l !== "").map(l => {
            const space = l.indexOf(" ");
            return {
                text: l,
                glyph: l.slice(0, space),
                name: l.slice(space + 1)
            };
        })
    }
}
