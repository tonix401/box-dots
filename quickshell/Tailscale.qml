pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Shared tailscale state for the bar and the start menu, so toggling in one updates the other.
// Polls too, to catch changes made from a terminal.
Singleton {
    id: root

    readonly property string status: poll.output // "up" / "down" ("" until the first check)
    readonly property bool up: status === "up"

    function toggle() {
        poll.act("bash ~/.config/waybar/scripts/toggle_tailscale.sh");
    }

    Poll {
        id: poll
        command: ["bash", Quickshell.env("HOME") + "/.config/waybar/scripts/tailscale_status.sh"]
        interval: 5000
    }
}
