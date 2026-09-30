import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components

// A small picture of the desktop: the wallpaper at the screen's aspect ratio with the widgets'
// dark band, and the options from the picture's left edge to the week calendar's column's right
// edge (shell.qml passes where that is), top to bottom, with the same inset on every side.
Menu {
    id: menu

    property rect calendarArea: Qt.rect(24, 51, 1320, 912) // on the screen; only its right edge is used
    property int fade: 160 // the band's fade right of the widgets, on the screen

    readonly property real screenWidth: screen?.width ?? 3440
    readonly property real screenHeight: screen?.height ?? 1440
    readonly property int inset: 6 // around the list
    // Screen pixels to picture pixels, chosen so the options fill the picture's height; the
    // picture sits inside the box's 2px border.
    readonly property real scale: (items.length * rowHeight + (items.length - 1) * listSpacing + 2 * inset) / screenHeight

    boxWidth: Math.round(screenWidth * scale) + 4
    boxHeight: Math.round(screenHeight * scale) + 4
    fontPt: 11
    rowPadV: 8
    rowPadH: 12
    showInput: false
    matching: "fuzzy"
    listArea: Qt.rect(2 + inset, 2 + inset, Math.round((calendarArea.x + calendarArea.width) * scale) - 2 * inset, boxHeight - 4 - 2 * inset)
    items: [
        {
            text: Theme.g(0xf0425) + "  Shutdown",
            cmd: "systemctl poweroff"
        },
        {
            text: Theme.g(0xf0709) + "  Reboot",
            cmd: "systemctl reboot"
        },
        {
            text: Theme.g(0xf035b) + "  Reboot into UEFI",
            cmd: "systemctl reboot --firmware-setup"
        },
        {
            text: Theme.g(0xf033e) + "  Lock",
            cmd: "hyprlock"
        },
        {
            text: Theme.g(0xf0343) + "  Log out",
            cmd: "hyprshutdown -vt 2"
        },
        {
            text: Theme.g(0xf16a1) + "  Kill open Apps",
            cmd: "hyprctl -j clients | jq -r '.[].pid' | xargs -r kill"
        }
    ]
    onAccepted: item => Util.run(item.cmd)

    backdrop: ClippingRectangle {
        radius: 10
        color: "transparent"

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.cache/box-dots/current/wallpaper.png"
            fillMode: Image.PreserveAspectCrop
            cache: false
            smooth: true
            mipmap: true
        }
        // The band behind the desktop widgets: from the screen's left edge to the column's right
        // edge, then fading out.
        Item {
            width: (menu.calendarArea.x + menu.calendarArea.width + menu.fade) * menu.scale
            height: parent.height

            Backdrop {
                fade: menu.fade * menu.scale
            }
        }
    }

    rowContent: MenuText {}
}
