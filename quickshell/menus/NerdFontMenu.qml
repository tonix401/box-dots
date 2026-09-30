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

    rowContent: MenuText {}

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/scripts/helpers/nerdfont.txt"
        onLoaded: root.items = text().split("\n").filter(l => l !== "").map(l => ({
                        text: l.replace(/ /g, "   ") // more space between icon and name
                    }))
    }
}
