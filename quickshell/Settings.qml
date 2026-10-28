pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shell features that can be switched off with the sidebar's toggles, remembered across
// restarts: the cats on kitty windows (KittyCat; `qs ipc call cat kitty` toggles it too) and the
// gif on the bar (modules/Gif.qml). Both cost CPU while shown. Also whether the sidebar's extras
// section is expanded.
Singleton {
    id: root

    property bool kittyCats: true
    property bool barGif: true
    property bool extrasOpen: true

    function set(key, value) {
        root[key] = value;
        state.setText(JSON.stringify({
            kittyCats: root.kittyCats,
            barGif: root.barGif,
            extrasOpen: root.extrasOpen
        }) + "\n");
    }

    FileView {
        id: state
        path: Quickshell.statePath("settings.json")
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.kittyCats = s.kittyCats ?? true;
                root.barGif = s.barGif ?? true;
                root.extrasOpen = s.extrasOpen ?? true;
            } catch (e) {}
        }
    }
}
