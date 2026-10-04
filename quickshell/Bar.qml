import QtQuick
import qs
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.modules

// Port of the powerline waybar (waybar/config.jsonc + style.css).
PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    // No top margin: the popouts' hover areas reach the screen edge; the bar sits Theme.barTop below it.
    margins {
        left: 8
        right: 8
    }
    implicitHeight: Theme.barTop + Theme.barHeight
    exclusiveZone: Theme.barTop + Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    Item {
        id: barArea
        y: Theme.barTop
        width: parent.width
        height: Theme.barHeight

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Theme.surface_container_lowest
        }

        // modules-left
        RowLayout {
            anchors.left: parent.left
            height: Theme.barHeight
            spacing: 0

            Arrow {
                glyph: 0xe0b6
                fg: Theme.primary
            }
            Segment {
                id: archSeg
                color: Theme.primary
                fg: Theme.on_primary
                Arch {
                    fg: archSeg.fg
                }
            }
            Arrow {
                glyph: 0xe0b0
                fg: Theme.primary
                bg: Theme.secondary
            }
            Segment {
                id: systemSeg
                color: Theme.secondary
                fg: Theme.on_secondary
                Cpu {
                    fg: systemSeg.fg
                }
                Memory {
                    fg: systemSeg.fg
                    Layout.leftMargin: 16
                }
            }
            Arrow {
                glyph: 0xe0b0
                fg: Theme.secondary
                bg: Theme.tertiary
            }
            Segment {
                id: mprisSeg
                color: Theme.tertiary
                fg: Theme.on_tertiary
                visible: mpris.player !== null
                Mpris {
                    id: mpris
                    fg: mprisSeg.fg
                    onClicked: mediaPopout.pinned = !mediaPopout.pinned
                }
            }
            Arrow {
                glyph: 0xe0b0
                fg: Theme.tertiary
                bg: Theme.surface_container_highest
            }
            Segment {
                id: windowSeg
                color: Theme.surface_container_highest
                fg: Theme.on_surface
                // Collapse to just the arrows around it when nothing is focused.
                visible: windowMod.text !== ""
                Window {
                    id: windowMod
                    fg: windowSeg.fg
                }
            }
            Arrow {
                glyph: 0xe0b0
                fg: Theme.surface_container_highest
            }
        }

        // modules-center
        Workspaces {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // modules-right
        RowLayout {
            anchors.right: parent.right
            height: Theme.barHeight
            spacing: 0

            Gif {
                Layout.rightMargin: 8
            }
            Arrow {
                glyph: 0xe0b2
                fg: Theme.surface_container
            }
            Segment {
                id: traySeg
                color: Theme.surface_container
                fg: Theme.on_surface
                Tray {
                    fg: traySeg.fg
                }
            }
            Arrow {
                glyph: 0xe0b2
                fg: Theme.surface_container_highest
                bg: Theme.surface_container
            }
            Segment {
                id: fcitxSeg
                color: Theme.surface_container_highest
                fg: Theme.on_surface
                Fcitx {
                    fg: fcitxSeg.fg
                }
            }
            Arrow {
                glyph: 0xe0b2
                fg: Theme.tertiary
                bg: Theme.surface_container_highest
            }
            Segment {
                id: connSeg
                color: Theme.tertiary
                fg: Theme.on_tertiary
                Bluetooth {
                    fg: connSeg.fg
                }
                Network {
                    id: networkMod
                    fg: connSeg.fg
                    Layout.leftMargin: 16
                    detailed: connPopout.open
                }
                Tailscale {
                    fg: connSeg.fg
                    Layout.leftMargin: 16
                }
            }
            Arrow {
                glyph: 0xe0b2
                fg: Theme.secondary
                bg: Theme.tertiary
            }
            Segment {
                id: audioSeg
                color: Theme.secondary
                fg: Theme.on_secondary
                Speaker {
                    fg: audioSeg.fg
                }
                Microphone {
                    fg: audioSeg.fg
                    Layout.leftMargin: 16
                }
            }
            Arrow {
                glyph: 0xe0b2
                fg: Theme.primary
                bg: Theme.secondary
            }
            Segment {
                id: clockSeg
                color: Theme.primary
                fg: Theme.on_primary
                Clock {
                    fg: clockSeg.fg
                    onClicked: calendarPopout.pinned = !calendarPopout.pinned
                }
            }
            Arrow {
                glyph: 0xe0b4
                fg: Theme.primary
            }
        }
    }

    // Declared after the bar so their hover areas lie on top of their segments.
    MediaPopout {
        id: mediaPopout
        segment: mprisSeg
        player: mpris.player
    }
    ConnPopout {
        id: connPopout
        segment: connSeg
        network: networkMod
    }
    AudioPopout {
        id: audioPopout
        segment: audioSeg
    }
    CalendarPopout {
        id: calendarPopout
        segment: clockSeg
    }
}
