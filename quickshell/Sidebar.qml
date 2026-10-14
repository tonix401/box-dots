pragma Singleton

import QtQuick
import Quickshell

// The right-hand drawer (SidePanel.qml). Opens while the pointer is on the screen's right edge or on
// the drawer, closing shortly after it leaves. A click on the bell, the media block or the clock (or
// `qs ipc call sidebar`) pins it open until it's toggled again or the pointer has been in and left.
Singleton {
    id: root

    property bool pinned: false
    property bool edgeHovered: false
    property bool panelHovered: false
    property bool open: false

    readonly property bool wanted: pinned || edgeHovered || panelHovered

    function toggle() {
        if (open)
            close();
        else
            pinned = true;
    }

    function close() {
        pinned = false;
        closeTimer.stop();
        open = false;
    }

    // Close with a short delay so the pointer can cross from the edge onto the drawer.
    onWantedChanged: {
        if (wanted) {
            closeTimer.stop();
            open = true;
        } else {
            closeTimer.restart();
        }
    }

    // Once the pointer is on a pinned drawer, hovering takes over: leaving closes it.
    onPanelHoveredChanged: if (panelHovered)
        pinned = false

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: root.open = false
    }
}
