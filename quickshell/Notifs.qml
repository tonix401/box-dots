pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon (org.freedesktop.Notifications), in place of swaync. Keeps every
// notification for the sidebar's history (SidePanel.qml) until it is dismissed, and lists the ones
// currently shown as toasts (NotificationPopups.qml). Do not disturb is remembered across restarts.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values.slice().reverse() // newest first
    property var popups: [] // shown as popups, newest first
    property var shownAt: ({}) // notification id -> Date it arrived
    property var left: ({}) // notification id -> ms its popup has left (0: stays until closed)
    property bool hovered: false // pointer on the popups: their time doesn't run out
    property bool dnd: false

    // Same timeouts as the swaync config this replaced: low 5s, normal 10s, critical never.
    function timeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000;
        return n.urgency === NotificationUrgency.Low ? 5000 : 10000;
    }

    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
        // Transient ones are only meant to be seen, not kept in the center.
        if (n.transient && n.tracked)
            n.expire();
    }

    // The default action (clicking the card), then close it like swaync's hide-on-action.
    function activate(n) {
        const action = n.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        if (!n.resident)
            n.dismiss();
        hidePopup(n);
        Sidebar.close();
    }

    function clearAll() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    function setDnd(on) {
        dnd = on;
        if (on)
            popups.filter(n => n.urgency !== NotificationUrgency.Critical).forEach(hidePopup);
        state.setText(JSON.stringify({
            dnd: on
        }) + "\n");
    }

    // App icon, or the sender's image. Theme icons resolve to "" when the theme lacks them, so
    // nothing is drawn instead of the missing-image checkerboard.
    function iconFor(n) {
        const themed = name => name.startsWith("/") ? "file://" + name : name.includes("/") ? name : Quickshell.iconPath(name, true);
        if (n.image)
            return n.image.startsWith("image://icon/") ? themed(n.image.slice(13)) : n.image;
        if (n.appIcon)
            return themed(n.appIcon);
        const entry = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        return entry ? themed(entry.icon) : "";
    }

    // The sidebar lists everything, so open toasts step aside while it's out.
    Connections {
        target: Sidebar
        function onOpenChanged() {
            if (Sidebar.open)
                root.popups.slice().forEach(root.hidePopup);
        }
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            root.shownAt[n.id] = new Date();
            n.closed.connect(() => root.popups = root.popups.filter(p => p !== n));
            if (Sidebar.open || (root.dnd && n.urgency !== NotificationUrgency.Critical)) {
                if (n.transient)
                    n.expire();
                return;
            }
            root.left[n.id] = root.timeout(n);
            // A replacement (same id) takes the old one's place instead of stacking.
            root.popups = [n].concat(root.popups.filter(p => p.id !== n.id));
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0 && !root.hovered
        onTriggered: {
            for (const n of root.popups.slice()) {
                const ms = root.left[n.id];
                if (ms <= 0)
                    continue;
                root.left[n.id] = ms - interval;
                if (ms - interval <= 0)
                    root.hidePopup(n);
            }
        }
    }

    FileView {
        id: state
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                root.dnd = JSON.parse(text()).dnd ?? false;
            } catch (e) {}
        }
    }
}
