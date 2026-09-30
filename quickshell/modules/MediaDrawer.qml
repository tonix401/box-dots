import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.components

// The mpris block growing down into the media card. Click on the block pins it.
Drawer {
    id: root

    required property MprisPlayer player

    available: player !== null
    card: false
    contentWidth: 360

    function time(seconds) {
        const s = Math.floor(seconds);
        const mm = String(Math.floor(s / 60) % 60).padStart(s >= 3600 ? 2 : 1, "0");
        const ss = String(s % 60).padStart(2, "0");
        return s >= 3600 ? `${Math.floor(s / 3600)}:${mm}:${ss}` : `${mm}:${ss}`;
    }

    // The card already shows the track, so the header has the player name and elapsed/total time.
    header: Item {
        BarText {
            x: 10
            height: parent.height
            width: timeLabel.x - x - 12
            elide: Text.ElideRight
            text: `${Theme.g(0xf075a)} ${root.player?.identity ?? ""}`
            color: root.segment.fg
        }

        BarText {
            id: timeLabel
            anchors.right: parent.right
            anchors.rightMargin: 10
            height: parent.height
            visible: (root.player?.lengthSupported ?? false) && root.player.length > 0
            text: visible ? `${root.time(root.player.position)} / ${root.time(root.player.length)}` : ""
            color: root.segment.fg
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => event.button === Qt.RightButton ? root.player?.togglePlaying() : root.pinned = !root.pinned
        }
    }

    MediaCard {
        width: parent.width
        height: 180
        player: root.player
        bordered: false
    }
}
