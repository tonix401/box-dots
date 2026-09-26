pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colors come from the matugen-generated waybar palette so both bars share one theme.
Singleton {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontPx: 15
    readonly property int arrowPx: 22
    readonly property int workspacePx: 13
    readonly property int barHeight: 30

    property var palette: ({})

    function c(name) {
        return palette[name] ?? "#ff00ff";
    }

    // Nerd font glyphs are kept as code points so no file ever contains the raw glyphs.
    function g(cp) {
        return String.fromCodePoint(cp);
    }

    readonly property color primary: c("primary")
    readonly property color on_primary: c("on_primary")
    readonly property color secondary: c("secondary")
    readonly property color on_secondary: c("on_secondary")
    readonly property color tertiary: c("tertiary")
    readonly property color on_tertiary: c("on_tertiary")
    readonly property color tertiary_fixed: c("tertiary_fixed")
    readonly property color error_container: c("error_container")
    readonly property color surface: c("surface")
    readonly property color on_surface: c("on_surface")
    readonly property color on_surface_variant: c("on_surface_variant")
    readonly property color outline: c("outline")
    readonly property color outline_variant: c("outline_variant")
    readonly property color surface_container_lowest: c("surface_container_lowest")
    readonly property color surface_container: c("surface_container")
    readonly property color surface_container_high: c("surface_container_high")
    readonly property color surface_container_highest: c("surface_container_highest")

    FileView {
        path: Quickshell.env("HOME") + "/.config/waybar/colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const out = {};
            const re = /@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})/g;
            let m;
            while ((m = re.exec(text())) !== null)
                out[m[1]] = m[2];
            root.palette = out;
        }
    }
}
