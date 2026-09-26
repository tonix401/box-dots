//@ pragma IconTheme Adwaita

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.menus

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Software dimming below the backlight minimum: a click-through black layer over everything.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-dim"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {} // no input region: clicks go through
            visible: Monitor.dim > 0
            color: Qt.rgba(0, 0, 0, Monitor.dim)
        }
    }

    // Brightness keys: `qs ipc call brightness change 8` / `-8`
    IpcHandler {
        target: "brightness"

        function change(percent: int): void {
            Monitor.change(percent);
        }
        function set(level: real): void {
            Monitor.setLevel(level);
        }
        function temperature(kelvin: int): void {
            Monitor.setTemperature(kelvin);
        }
    }

    // Replacements for the rofi menus: `qs ipc call menu toggle <name>`.
    IpcHandler {
        target: "menu"

        function open(name: string): void {
            Menus.open(name);
        }
        function toggle(name: string): void {
            Menus.toggle(name);
        }
        function close(): void {
            Menus.close();
        }
    }

    // Each menu is created when opened and destroyed when closed, so it reloads its data every time like rofi.
    LazyLoader {
        active: Menus.active === "power"
        PowerMenu {}
    }

    LazyLoader {
        active: Menus.active === "launcher"
        StartMenu {}
    }
    LazyLoader {
        active: Menus.active === "keybinds"
        KeybindsMenu {}
    }
    LazyLoader {
        active: Menus.active === "clipboard"
        ClipboardMenu {}
    }
    LazyLoader {
        active: Menus.active === "emoji"
        EmojiMenu {}
    }
    LazyLoader {
        active: Menus.active === "nerdfont"
        NerdFontMenu {}
    }
    LazyLoader {
        active: Menus.active === "wallpaper"
        WallpaperMenu {}
    }
}
