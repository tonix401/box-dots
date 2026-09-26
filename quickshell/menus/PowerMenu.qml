import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components

// hypr/scripts/rofi/power-menu.py + rofi/powermenu.rasi
Menu {
    boxWidth: 720
    fontPt: 13
    showInput: false
    matching: "fuzzy"
    lines: 6
    fixedHeight: false
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

    side: ClippingRectangle {
        radius: 8
        color: "transparent"

        // background-image: url(wallpaper-square.png, width) — scaled to the width, drawn from the top
        Image {
            width: parent.width
            height: width
            source: "file://" + Quickshell.env("HOME") + "/.cache/box-dots/current/wallpaper-square.png"
            cache: false
            smooth: true
            mipmap: true
        }
    }

    rowContent: MenuText {}
}
