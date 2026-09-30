import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

Module {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    // Every input device, so muting covers all mics, not just the default one.
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    text: source?.audio?.muted ? Theme.g(0xf131) + "  muted" : Theme.g(0xf130) + " listen"
    onClicked: {
        const muted = !(source?.audio?.muted ?? false);
        for (const n of inputs)
            n.audio.muted = muted;
    }
    onRightClicked: Util.run("pavucontrol")

    PwObjectTracker {
        objects: root.inputs
    }
}
