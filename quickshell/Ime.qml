pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// fcitx5's input method, read from and switched through its tray item, so nothing polls: the
// item's icon follows the active IM, scrolling it steps through the profile's IMs and activating
// it toggles between the first IM (keyboard-us) and the last other one.
Singleton {
    id: root

    readonly property SystemTrayItem item: SystemTray.items.values.find(i => i.id === "Fcitx") ?? null
    readonly property bool english: /input-keyboard/.test(item?.icon ?? "")
    readonly property string label: {
        const icon = item?.icon ?? "";
        if (!item)
            return "--";
        if (english)
            return "EN";
        if (/mozc/.test(icon))
            return "JP";
        if (/pinyin/.test(icon))
            return "CN";
        return item.tooltipTitle; // an IM added to the profile later
    }

    function cycle() {
        item?.scroll(120, false);
    }

    function toEnglish() {
        if (!english)
            item?.activate();
    }

    // CTRL+SPACE in hypr/keybinds.lua: hl.dsp.global("quickshell:cycleInputMethod")
    GlobalShortcut {
        name: "cycleInputMethod"
        description: "Cycle input method"
        onPressed: root.cycle()
    }
}
