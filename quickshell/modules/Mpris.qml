import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.components

Module {
    id: root

    // playerctld only mirrors another player
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property string statusIcon: {
        if (!player)
            return "";
        switch (player.playbackState) {
        case MprisPlaybackState.Playing:
            return Theme.g(0xf04b);
        case MprisPlaybackState.Paused:
            return Theme.g(0xf04c);
        default:
            return Theme.g(0xf04d);
        }
    }

    text: player ? Util.truncate(`${statusIcon} ${player.trackArtist} ~ ${player.trackTitle}`, Theme.titleChars) : ""
    onRightClicked: player?.togglePlaying()
}
