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
    matchText: it => [it.description.replace(/\s*<small>.*<\/small>/, ""), (it.description.match(/<small>(.*)<\/small>/) ?? ["", ""])[1]] // name, keywords

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
            textFormat: Text.StyledText
            text: row.entry.description.replace(/\s*<small>.*<\/small>/, "") // keywords stay searchable, just not shown
            color: row.selected ? Theme.on_primary : Theme.primary
            font.family: Theme.uiFont
            font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
            font.pointSize: row.fontPt
            renderType: Theme.renderType
        }
    }

    Process {
        running: true
        command: [root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.items = JSON.parse(text).map(([char, description]) => ({
                            char: char,
                            description: description
                        }))
        }
    }
}
