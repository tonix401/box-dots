import QtQuick
import qs

// element-text: primary, on_primary when selected, elided at the end.
Text {
    property var entry: parent.entry
    property bool selected: parent.selected

    width: parent.width
    height: parent.height
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    text: entry.text
    color: selected ? Theme.on_primary : Theme.primary
    font.family: Theme.fontFamily
    font.hintingPreference: Font.PreferFullHinting // pango rounds advances to whole pixels
    font.pointSize: parent.fontPt
    renderType: Text.NativeRendering
}
