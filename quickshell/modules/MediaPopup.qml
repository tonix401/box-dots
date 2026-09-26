import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.components

// The media card under the mpris block: opens on hover, click on the block pins it.
PopupWindow {
    id: root

    required property Item target
    required property MprisPlayer player
    property bool hoverSource: false // is the pointer on the bar block?
    property bool pinned: false // toggled by clicking the bar block

    readonly property bool wanted: player !== null && (pinned || hoverSource || card.hovered)
    property bool open: false

    // Close with a short delay so the pointer can cross the gap between bar and popup.
    onWantedChanged: {
        if (wanted) {
            closeTimer.stop();
            open = true;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: root.open = false
    }

    // Extend the anchor below the bar by hyprland's gaps_out (8) so the top lines up with window borders.
    // (anchor.margins shrink the anchor rect, they don't add a gap.)
    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 8
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    visible: open && player !== null
    color: "transparent"
    implicitWidth: 360
    implicitHeight: 180

    MediaCard {
        id: card
        anchors.fill: parent
        player: root.player
    }
}
