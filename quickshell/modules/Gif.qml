import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.components

// An animated gif on the bar (what waybar's cffi/dance-gif plugin did). Shows the gifs in
// ~/.cache/box-dots/, which waybar/scripts/gif-watch.sh scales to bar height from ~/Pictures/waybar-gifs.
// Click for the next one, right-click for the previous; the choice is remembered.
Item {
    id: root

    property string chosen: "" // file name of the selected gif

    property var names: [] // gif file names, filled once the folder is read
    readonly property int count: names.length
    readonly property int index: Math.max(0, names.indexOf(chosen))

    function pick(step) {
        if (count === 0)
            return;
        chosen = names[(index + step + count) % count];
        saved.setText(chosen + "\n");
    }

    implicitWidth: count > 0 ? image.implicitWidth * Theme.barHeight / Math.max(1, image.implicitHeight) : 0
    implicitHeight: Theme.barHeight
    visible: count > 0

    FolderListModel {
        id: gifs
        folder: "file://" + Quickshell.env("HOME") + "/.cache/box-dots"
        nameFilters: ["*.gif", "*.GIF"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready)
            root.names = Array.from({
                length: count
            }, (_, i) => get(i, "fileName"))
        onCountChanged: if (status === FolderListModel.Ready)
            root.names = Array.from({
                length: count
            }, (_, i) => get(i, "fileName"))
    }

    AnimatedImage {
        id: image
        anchors.fill: parent
        source: root.count > 0 ? gifs.folder + "/" + root.names[root.index] : ""
        fillMode: Image.PreserveAspectFit
        playing: root.visible
        cache: false
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => root.pick(event.button === Qt.RightButton ? -1 : 1)
    }

    FileView {
        id: saved
        path: Quickshell.statePath("bar-gif.txt")
        printErrors: false
        onLoaded: root.chosen = text().trim()
    }
}
