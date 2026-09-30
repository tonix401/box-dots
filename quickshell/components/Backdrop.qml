import QtQuick

// A desktop widget's share of the dark band behind the widgets (keeps their text readable on any
// wallpaper): solid, except for the last `fade` px on the right, which fade out. The widgets'
// windows tile the band, so their backdrops read as one shadow.
Item {
    id: backdrop

    property int fade: 0
    readonly property color dark: Qt.alpha("black", 0.75)

    anchors.fill: parent

    Rectangle {
        width: parent.width - backdrop.fade
        height: parent.height
        color: backdrop.dark
    }
    Rectangle {
        x: parent.width - backdrop.fade
        width: backdrop.fade
        height: parent.height
        visible: backdrop.fade > 0
        // Eased rather than linear, so the band has no visible edge where the fade starts or ends.
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: backdrop.dark
            }
            GradientStop {
                position: 0.3
                color: Qt.alpha("black", 0.75 * 0.75)
            }
            GradientStop {
                position: 0.6
                color: Qt.alpha("black", 0.75 * 0.3)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
}
