import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs
import "CatEngine.js" as Engine

// The cat avatar drawn from its rig (~/.config/cat/rig.json, built from rig.svg; see SPEC.md there),
// in the theme's primary color. `expression` picks one of the rig's expressions; `act("hop" | "jolt",
// count)` plays a motion; `press(true/false)` squishes it while held and lets it boing back.
//
// All the animation is CatEngine.js (generated from ~/.config/cat/engine.js, shared with the
// browser preview): each frame it returns part matrices, moved paths and opacities, and this only
// draws them.
Item {
    id: root

    property string expression: "neutral"
    property color color: Theme.primary
    property bool squished: false // held squished while true; boings back when it turns false

    property var rig: null
    property var engine: null // the engine's state
    property var frame: ({
            worlds: {},
            paths: {},
            variantOpacity: {},
            partOpacity: {},
            shapeOpacity: {}
        })
    readonly property var canvas: rig?.canvas ?? [0, 0, 1, 1]

    implicitWidth: 200
    implicitHeight: implicitWidth * canvas[3] / canvas[2]

    function act(motion, count) {
        if (engine)
            Engine.CatEngine.act(engine, motion, count ?? 1);
    }
    function press(down) {
        if (engine)
            Engine.CatEngine.press(engine, down);
    }
    function matrix(m) {
        return m ? Qt.matrix4x4(m[0], m[2], 0, m[4], m[1], m[3], 0, m[5], 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4();
    }

    onExpressionChanged: if (engine)
        Engine.CatEngine.setExpression(engine, expression)
    onSquishedChanged: press(squished)

    FileView {
        path: Quickshell.env("HOME") + "/.config/cat/rig.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // build.py may be caught mid-write: keep the last rig until the file parses.
            try {
                const rig = JSON.parse(text());
                root.engine = Engine.CatEngine.create(rig, root.expression);
                Engine.CatEngine.press(root.engine, root.squished);
                root.rig = rig;
                root.frame = Engine.CatEngine.step(root.engine, 0);
            } catch (e) {}
        }
    }

    FrameAnimation {
        running: root.visible && root.engine !== null
        onTriggered: root.frame = Engine.CatEngine.step(root.engine, Math.min(frameTime, 0.1))
    }

    // The rig's coordinates, scaled into this item.
    Item {
        transform: Matrix4x4 {
            readonly property real s: root.width / root.canvas[2]
            matrix: Qt.matrix4x4(s, 0, 0, -root.canvas[0] * s, 0, s, 0, -root.canvas[1] * s, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        Repeater {
            model: root.rig?.order ?? []

            Item {
                id: partItem
                required property string modelData
                readonly property var part: root.rig.parts[modelData]

                opacity: root.frame.partOpacity[modelData] ?? 1
                visible: opacity > 0.01
                transform: Matrix4x4 {
                    matrix: root.matrix(root.frame.worlds[partItem.modelData])
                }

                Repeater {
                    model: Object.keys(partItem.part.variants)

                    Item {
                        id: variantItem
                        required property string modelData
                        readonly property var shapes: partItem.part.variants[modelData]
                        readonly property var moved: root.frame.paths[partItem.modelData]?.[modelData]

                        opacity: root.frame.variantOpacity[partItem.modelData + "/" + modelData] ?? 0
                        visible: opacity > 0.01

                        Repeater {
                            model: variantItem.shapes.length

                            Shape {
                                required property int index
                                readonly property var shape: variantItem.shapes[index]

                                preferredRendererType: Shape.CurveRenderer
                                opacity: root.frame.shapeOpacity[partItem.modelData + "/" + index] ?? 1

                                ShapePath {
                                    strokeColor: shape.stroke ? root.color : "transparent"
                                    strokeWidth: shape.stroke ? 2 : -1
                                    fillColor: shape.fill ? Qt.alpha(root.color, shape.alpha) : "transparent"
                                    fillRule: shape.evenodd ? ShapePath.OddEvenFill : ShapePath.WindingFill
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: shape.join === "round" ? ShapePath.RoundJoin : ShapePath.MiterJoin

                                    PathSvg {
                                        path: variantItem.moved?.[index] ?? shape.d
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
