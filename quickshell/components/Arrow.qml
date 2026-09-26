import QtQuick
import QtQuick.Shapes
import qs

// A powerline separator: `bg` is the neighbour it sits against, `fg` the one it points into.
// Drawn as a shape instead of the nerd-font glyph so it lands on whole pixels (no seams);
// 14px wide matches waybar's rendering of the glyph at 22px.
Rectangle {
    id: root

    property int glyph // 0xe0b0 ▶, 0xe0b2 ◀, 0xe0b6 left round cap, 0xe0b4 right round cap
    property color fg
    property color bg: "transparent"

    readonly property bool round: glyph === 0xe0b6 || glyph === 0xe0b4
    // Side the flat edge sits on: left for ▶ and the right cap, right for ◀ and the left cap.
    readonly property real baseX: glyph === 0xe0b0 || glyph === 0xe0b4 ? 0 : width

    implicitWidth: 14
    implicitHeight: Theme.barHeight
    color: bg

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fg
            strokeWidth: -1
            startX: root.baseX
            startY: 0

            PathLine {
                x: root.round ? root.baseX : root.width - root.baseX
                y: root.round ? 0 : root.height / 2
            }
            PathArc {
                x: root.baseX
                y: root.height
                radiusX: root.round ? root.width : 0
                radiusY: root.round ? root.height / 2 : 0
                direction: root.baseX === 0 ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }
}
