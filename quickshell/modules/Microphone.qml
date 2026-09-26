import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

Module {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource

    text: source?.audio?.muted ? Theme.g(0xf131) + "  muted" : Theme.g(0xf130) + " listen"
    onClicked: Util.run("bash ~/.config/waybar/scripts/toggle_mute_mics.sh")
    onRightClicked: Util.run("pavucontrol")

    PwObjectTracker {
        objects: [root.source]
    }
}
