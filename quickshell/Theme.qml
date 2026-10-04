pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colors come from colors.json, which matugen generates from
// ~/.config/matugen/templates/colors-quickshell.json on every wallpaper change.
Singleton {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font" // the bar, and glyphs everywhere
    readonly property string uiFont: "Adwaita Sans" // text in menus, popups and widgets (the GTK UI font)
    readonly property string monoFont: "Adwaita Mono" // menus whose columns line up with spaces
    readonly property int fontPx: 15
    readonly property int arrowPx: 22
    readonly property int workspacePx: 13
    readonly property int barHeight: 30
    readonly property int barTop: 5 // gap between the screen edge and the bar

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
    readonly property color error: c("error")
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
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // matugen rewrites the file in place, so a change can be seen half-written: keep the
            // last palette until it parses.
            try {
                root.palette = JSON.parse(text());
            } catch (e) {}
        }
    }
}
