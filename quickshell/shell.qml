//@ pragma IconTheme Adwaita

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.menus

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Desktop widgets, hidden together with `qs ipc call widgets toggle` (SUPER+D). The week
    // calendar sits top left under the bar, the todo list and the habit tracker side by side below
    // it down to the screen's bottom. Their windows reach to the screen's edges and meet halfway
    // across the gaps, so their backdrops make one dark band from top to bottom that fades out
    // right of the column.
    readonly property int edge: Theme.compact ? 16 : 24 // from the screen's left and bottom edges
    readonly property int gap: Theme.compact ? 12 : 16 // between the widgets and below the bar
    readonly property int fade: 160 // the band's fade right of the widgets

    WeekCalendar {
        id: calendar
        visible: Desktop.widgetsShown
        anchors.top: true
        anchors.left: true
        room: ({
                left: root.edge,
                top: Theme.barTop + Theme.barHeight + root.gap, // up to the screen's top, behind the bar
                right: root.fade,
                bottom: root.gap / 2
            })
        fade: root.fade
    }

    TodoList {
        id: todo
        visible: Desktop.widgetsShown
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        margins.top: calendar.implicitHeight
        panelWidth: calendar.panelWidth - root.gap - habits.size
        room: ({
                left: root.edge,
                top: root.gap / 2,
                right: root.gap / 2,
                bottom: root.edge
            })
    }

    HabitTracker {
        id: habits
        visible: Desktop.widgetsShown
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        margins.top: calendar.implicitHeight
        margins.left: todo.implicitWidth
        room: ({
                left: root.gap / 2,
                top: root.gap / 2,
                right: root.fade,
                bottom: root.edge
            })
        fade: root.fade
    }

    // Notification popups; the center is created when opened (bell in the bar).
    NotificationPopups {}

    LazyLoader {
        active: Notifs.centerOpen
        NotificationCenter {}
    }

    // Software dimming below the backlight minimum: a click-through black layer over everything.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-dim"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {} // no input region: clicks go through
            visible: Monitor.dim > 0
            color: Qt.rgba(0, 0, 0, Monitor.dim)
        }
    }

    // Brightness keys: `qs ipc call brightness change 8` / `-8`
    IpcHandler {
        target: "brightness"

        function change(percent: int): void {
            Monitor.change(percent);
        }
        function set(level: real): void {
            Monitor.setLevel(level);
        }
        function temperature(kelvin: int): void {
            Monitor.setTemperature(kelvin);
        }
    }

    // Desktop widgets: `qs ipc call widgets toggle` / `open` / `close` (`show` would clash with qs's own
    // `ipc show`).
    IpcHandler {
        target: "widgets"

        function toggle(): void {
            Desktop.toggle();
        }
        function open(): void {
            Desktop.setShown(true);
        }
        function close(): void {
            Desktop.setShown(false);
        }
    }

    // Notification center and do not disturb: `qs ipc call notifications toggle` / `dnd` / `clear`.
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            Notifs.toggleCenter();
        }
        function close(): void {
            Notifs.centerOpen = false;
        }
        function dnd(): void {
            Notifs.setDnd(!Notifs.dnd);
        }
        function clear(): void {
            Notifs.clearAll();
        }
    }

    // Replacements for the rofi menus: `qs ipc call menu toggle <name>`.
    IpcHandler {
        target: "menu"

        function open(name: string): void {
            Menus.open(name);
        }
        function toggle(name: string): void {
            Menus.toggle(name);
        }
        function close(): void {
            Menus.close();
        }
    }

    // Screen-share requests from the portal's picker script (hypr/scripts/share-picker.sh); see Share.qml.
    // Answers "ok" so the script knows the menu took it, and falls back to hyprland-share-picker otherwise.
    IpcHandler {
        target: "share"

        function pick(fifo: string, windows: string, allowToken: bool): string {
            Share.request(fifo, windows, allowToken);
            return "ok";
        }
    }

    // Each menu is created when opened and destroyed when closed, so it reloads its data every time like rofi.
    LazyLoader {
        active: Menus.active === "power"
        PowerMenu {
            // Its options go where the calendar is on the desktop.
            calendarArea: Qt.rect(root.edge, calendar.room.top, calendar.panelWidth, calendar.panelHeight)
            fade: root.fade
        }
    }

    LazyLoader {
        active: Menus.active === "launcher"
        StartMenu {}
    }
    LazyLoader {
        active: Menus.active === "keybinds"
        KeybindsMenu {}
    }
    LazyLoader {
        active: Menus.active === "clipboard"
        ClipboardMenu {}
    }
    LazyLoader {
        active: Menus.active === "emoji"
        EmojiMenu {}
    }
    LazyLoader {
        active: Menus.active === "nerdfont"
        NerdFontMenu {}
    }
    LazyLoader {
        active: Menus.active === "wallpaper"
        WallpaperMenu {}
    }
    LazyLoader {
        active: Menus.active === "share"
        ShareMenu {}
    }
}
