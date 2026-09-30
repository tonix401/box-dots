import QtQuick
import Quickshell
import Quickshell.Io
import qs

// hypr/scripts/rofi/emoji-picker-menu.py (rofimoji, clipboard action, neutral skin tone) + rofi/emoji.rasi
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

    rowContent: Text {
        property var entry: parent.entry
        property bool selected: parent.selected

        width: parent.width
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.StyledText
        text: entry.char + " " + entry.description.replace(/\s*<small>.*<\/small>/, "") // keywords stay searchable, just not shown
        color: selected ? Theme.on_primary : Theme.primary
        font.family: Theme.fontFamily
        font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
        font.pointSize: parent.fontPt
        renderType: Text.NativeRendering
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
