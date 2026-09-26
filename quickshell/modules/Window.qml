import QtQuick
import Quickshell.Wayland
import qs
import qs.components

Module {
    id: root

    // The Wayland toplevel protocol knows the focused window at startup; Hyprland IPC only after the next focus change.
    readonly property Toplevel win: ToplevelManager.activeToplevel?.activated ? ToplevelManager.activeToplevel : null
    readonly property string cls: win?.appId ?? ""

    // Same rewrite table as waybar/modules/window.jsonc (class regex -> icon).
    readonly property var rewrites: [
        [/^(kitty|Alacritty|konsole)$/, 0xf018d],
        [/^(code|codium)$/, 0xf0a1e],
        [/^(mousepad|obsidian|Obsidian)$/, 0xf14e7],
        [/^(firefox|Firefox)$/, 0xe658],
        [/^(chromium|chrome|Chromium)$/, 0xf268],
        [/^(nemo|Nemo)$/, 0xf07b],
        [/^(org\.inkscape\.Inkscape)$/, 0xf1fc],
        [/^(org\.kde\.Kdenlive)$/, 0xf0381],
        [/^(org\.musicbrainz\.Picard)$/, 0xf001],
        [/^(vlc|VLC|mpv)$/, 0xf057c],
        [/^(blueman-manager)$/, 0xf293],
        [/^(org\.pulseaudio\.pavucontrol)$/, 0xf1542],
        [/^(nm-connection-editor)$/, 0xf043b],
        [/^(nwg-look|qt5ct|qt6ct|qdbusviewer)$/, 0xf0493]
    ]

    function format(cls, title) {
        const hit = rewrites.find(r => r[0].test(cls));
        return hit ? `${Theme.g(hit[1])} ${title}` : `${Theme.g(0xf02a0)} ${cls} - ${title}`;
    }

    text: win && win.title ? Util.truncate(format(cls, win.title), 30) : ""
}
