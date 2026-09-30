import QtQuick
import qs

// A bar segment growing down into a panel. Lies over `segment` (from the screen edge down, so
// hovering the gap above the bar counts too) and the space below it; the segment should take
// `segmentWidth` as its Layout.preferredWidth. Opens on hover, `pinned` keeps it open.
Item {
    id: root

    required property Item segment
    property bool available: true // e.g. only while a media player exists
    property bool pinned: false
    property bool alignRight: false // keep the content still against the right edge (right-hand modules)
    property bool card: true // put the content on a surface card; off for content that brings its own
    property int contentWidth: 300
    // Replaces the segment's own text while open (the bar fades that out itself).
    property Component header: null
    default property alias content: inner.data

    readonly property int padding: 8
    readonly property int inset: card ? 14 : 0
    readonly property int fullWidth: Math.max(segment.implicitWidth, contentWidth + 2 * (padding + inset))
    readonly property int fullHeight: Math.ceil(inner.height) + 2 * inset + 4 + padding
    // Rounded (like the tray drawer) so every frame lands on whole pixels; fractional widths
    // made everything next to the block wobble while it grew.
    readonly property int segmentWidth: Math.round(segment.implicitWidth + expansion * (fullWidth - segment.implicitWidth))

    readonly property bool wanted: available && (pinned || hover.hovered)
    property bool open: false
    property real expansion: open && available ? 1 : 0

    Behavior on expansion {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // Close with a short delay so the pointer can move between the block and the panel.
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
    height: Theme.barTop + Theme.barHeight + body.height
    visible: segment.visible

    HoverHandler {
        id: hover
    }

    Item {
        y: Theme.barTop
        width: parent.width
        height: Theme.barHeight
        visible: root.expansion > 0
        opacity: root.expansion

        // While open a left click on the block pins the drawer (and never reaches modules the header
        // faded out). Wheel and right clicks still go through: no wheel handler, left button only.
        MouseArea {
            anchors.fill: parent
            onClicked: root.pinned = !root.pinned
        }

        Loader {
            anchors.fill: parent
            active: root.header !== null
            sourceComponent: root.header
        }
    }

    Item {
        id: body

        y: Theme.barTop + Theme.barHeight
        width: parent.width
        height: Math.round(root.expansion * root.fullHeight)
        visible: height > 0
        clip: true

        // Anchored to the bottom so the content slides out from under the bar.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.fullHeight
            color: root.segment.color
            bottomLeftRadius: 20
            bottomRightRadius: 20

            Rectangle {
                x: (root.alignRight ? parent.width - root.fullWidth : 0) + root.padding
                y: 4
                width: root.fullWidth - 2 * root.padding
                height: root.fullHeight - 4 - root.padding
                radius: 12
                color: root.card ? Theme.surface_container : "transparent"

                Item {
                    id: inner
                    x: root.inset
                    y: root.inset
                    width: parent.width - 2 * root.inset
                    height: childrenRect.height
                }
            }
        }
    }
}
