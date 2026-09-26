import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

// waybar group/tray-group drawer: the notification icon leads, tray icons slide out to its left on hover.
Row {
    id: root

    property color fg
    property string alt: "none"

    readonly property var icons: ({
            "notification": 0xf116b,
            "none": 0xf03d6,
            "dnd-notification": 0xf00a0,
            "dnd-none": 0xf0a93,
            "inhibited-notification": 0xf009b,
            "inhibited-none": 0xf0a91,
            "dnd-inhibited-notification": 0xf009b,
            "dnd-inhibited-none": 0xf0a91
        })

    height: Theme.barHeight

    HoverHandler {
        id: hover
    }

    Item {
        id: drawer

        // Animate progress and round the width so every frame lands on whole pixels;
        // fractional widths made the whole right side wobble while sliding.
        property real progress: hover.hovered ? 1 : 0

        height: parent.height
        width: Math.round(progress * (items.implicitWidth + 10))
        clip: true

        Behavior on progress {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: items
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Repeater {
                model: SystemTray.items

                IconImage {
                    id: icon

                    required property SystemTrayItem modelData

                    implicitSize: 16
                    source: modelData.icon

                    // GTK recolors symbolic icons with the text color; do the same.
                    layer.enabled: String(source).includes("-symbolic")
                    layer.effect: MultiEffect {
                        brightness: 1
                        colorization: 1
                        colorizationColor: root.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: event => {
                            if (event.button === Qt.MiddleButton)
                                icon.modelData.secondaryActivate();
                            else if (event.button === Qt.RightButton || icon.modelData.onlyMenu)
                                menu.open();
                            else
                                icon.modelData.activate();
                        }
                        onWheel: event => icon.modelData.scroll(event.angleDelta.y, false)
                    }

                    QsMenuAnchor {
                        id: menu
                        menu: icon.modelData.menu
                        anchor.item: icon
                        anchor.rect.width: icon.width
                        anchor.rect.height: icon.height
                        anchor.edges: Edges.Bottom
                        anchor.gravity: Edges.Bottom
                        anchor.margins.top: 12
                    }
                }
            }
        }
    }

    Module {
        fg: root.fg
        text: Theme.g(root.icons[root.alt] ?? 0xf03d6) + " "
        onClicked: Util.run("swaync-client -t -sw")
        onRightClicked: Util.run("swaync-client -d -sw")
    }

    Process {
        command: ["swaync-client", "-swb"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.alt = JSON.parse(line).alt;
                } catch (e) {}
            }
        }
    }
}
