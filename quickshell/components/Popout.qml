import QtQuick
import Quickshell
import qs

// A floating info menu below a bar segment. Lies over `segment` (from the screen edge down, so
// hovering the gap above the bar counts too) without taking its clicks. Opens on hover and stays
// open while the pointer is on the card; `pinned` keeps it open.
Item {
    id: root

    required property Item segment
    property bool available: true // e.g. only while a media player exists
    property bool pinned: false
    property bool alignRight: false // hang from the segment's right edge (right-hand modules)
    property int contentWidth: 300
    // Optional row above the content, under its own divider.
    property Component header: null
    default property alias content: inner.data

    readonly property int padding: 14
    readonly property int gap: 8 // between the bar and the card
    readonly property int slide: 6 // the card drops in from this far up

    readonly property bool wanted: available && (pinned || barHover.hovered || cardHover.hovered)
    property bool open: false
    property real shown: open && available ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    // Close with a short delay so the pointer can move between the block and the card.
    onWantedChanged: {
        if (wanted) {
            closeTimer.stop();
            open = true;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: root.open = false
    }

    x: segment.parent.x + segment.x
    width: segment.width
    height: Theme.barTop + Theme.barHeight
    visible: segment.visible

    HoverHandler {
        id: barHover
    }

    PopupWindow {
        anchor.item: root.segment
        // Margins shrink the anchor rect rather than adding a gap, so grow the rect instead.
        anchor.rect.width: root.segment.width
        anchor.rect.height: root.segment.height + root.gap - root.slide
        anchor.edges: Edges.Bottom | (root.alignRight ? Edges.Right : Edges.Left)
        anchor.gravity: Edges.Bottom | (root.alignRight ? Edges.Left : Edges.Right)

        visible: root.shown > 0
        color: "transparent"
        implicitWidth: card.width
        implicitHeight: card.height + root.slide

        Rectangle {
            id: card

            y: root.slide * root.shown
            width: root.contentWidth + 2 * root.padding
            height: column.height + 2 * root.padding
            opacity: root.shown
            radius: 16
            color: Theme.surface_container
            border.width: 1
            border.color: Theme.outline_variant

            HoverHandler {
                id: cardHover
            }

            Column {
                id: column
                x: root.padding
                y: root.padding
                width: root.contentWidth
                spacing: 10

                Loader {
                    width: parent.width
                    height: Theme.barHeight
                    active: root.header !== null
                    visible: active
                    sourceComponent: root.header
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    visible: root.header !== null
                    color: Theme.outline_variant
                }

                Item {
                    id: inner
                    width: parent.width
                    height: childrenRect.height
                }
            }
        }
    }
}
