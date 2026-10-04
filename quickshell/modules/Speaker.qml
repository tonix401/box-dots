import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

Module {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    // Every output device, so muting covers all of them, not just the default one.
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool headphone: {
        const p = sink?.properties ?? {};
        const hay = [p["node.name"], p["device.form-factor"], p["device.form_factor"], p["device.profile.name"], sink?.description].join(" ").toLowerCase();
        // Bluetooth sinks don't carry the device form factor; treat them as headphones like waybar does.
        return /head(phone|set)|hands-?free|^bluez_output/.test(hay);
    }

    text: {
        if (muted)
            return `${Theme.g(0xeee8)} ${volume}%`;
        const icon = headphone ? 0xf02cb : Util.bucket([0xf026, 0xf027, 0xf028], volume);
        return `${Theme.g(icon)} ${volume}%`;
    }
    onClicked: {
        const mute = !muted;
        for (const n of outputs)
            n.audio.muted = mute;
    }
    onRightClicked: Util.run("pavucontrol")
    onScrolled: (dx, dy) => {
        if (sink?.audio && dy !== 0)
            sink.audio.volume = Math.max(0, Math.min(150, volume + 5 * dy)) / 100;
    }

    PwObjectTracker {
        objects: root.outputs
    }
}
