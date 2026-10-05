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
    // Smaller bar and desktop widgets while only small screens are connected, like the laptop's
    // 1920x1080 panel at scale 1.5 (1280x720 logical).
    readonly property bool compact: Quickshell.screens.every(s => s.height < 900)
    readonly property int fontPx: compact ? 11 : 15
    readonly property int arrowPx: compact ? 18 : 22
    readonly property int workspacePx: compact ? 10 : 13
    readonly property int barHeight: compact ? 22 : 30
    readonly property int barTop: compact ? 4 : 5 // gap between the screen edge and the bar
    readonly property int segmentPad: compact ? 6 : 10 // inside a powerline block
    readonly property int moduleGap: compact ? 8 : 16 // between the modules of one block
    readonly property int titleChars: compact ? 20 : 30 // window title and media in the bar
    readonly property real popoutScale: compact ? 0.8 : 1 // the info cards under the bar, as a whole
    readonly property real widgetScale: compact ? 0.8 : 1 // the desktop widgets' contents, as a whole
    // Native (hinted) text snaps every glyph to the pixel grid, which looks uneven at fractional
    // scales and when scaled down; Qt's own rendering places them smoothly there.
    readonly property int renderType: popoutScale !== 1 || Quickshell.screens.some(s => s.devicePixelRatio % 1 !== 0) ? Text.QtRendering : Text.NativeRendering

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
