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

    // Desktop widgets, hidden together with `qs ipc call widgets toggle` (SUPER+D), while OBS runs
    // (Privacy, so they stay off stream) and while a tiled window is on the desktop (Desktop.covered).
    // The week calendar sits top left under the bar, the todo list and the habit tracker side by side
    // below it down to the screen's bottom. Their windows reach to the screen's edges and meet halfway
    // across the gaps, so their backdrops make one dark band from top to bottom that fades out right
    // of the column.
    //
    // The whole layout is worked out here, from the screen's size and the calendar's content alone:
    // each widget gets its panel's size and draws only from that, never from its own window's size.
    // Hyprland confirms a window's size a moment after it is shown (until then it is a default), and
    // a layout chained through those sizes resized twice on every show and once got stuck halfway.
    readonly property int edge: 24 // from the screen's left and bottom edges
    readonly property int gap: 16 // between the widgets and below the bar
    readonly property int fade: 160 // the band's fade right of the widgets
    readonly property bool widgetsVisible: Desktop.widgetsShown && !Desktop.covered && !Privacy.active
    readonly property int screenWidth: Quickshell.screens[0]?.width ?? 1920
    readonly property int screenHeight: Quickshell.screens[0]?.height ?? 1080
    // The column's width, shared by the calendar above and the todo list and habit tracker below.
    readonly property int columnWidth: Math.max(640, Math.min(1320, screenWidth - 2 * edge - fade))
    // The panels below the calendar: as tall as what is left of the screen; the habit tracker square
    // where it can be, but never more than 40 % of the column or less than 280 px.
    readonly property int lowerHeight: Math.max(0, screenHeight - calendar.implicitHeight - gap / 2 - edge)
    readonly property int habitsWidth: Math.max(280, Math.min(lowerHeight, Math.round(columnWidth * 0.4)))

    WeekCalendar {
        id: calendar
        visible: root.widgetsVisible
        anchors.top: true
        anchors.left: true
        panelWidth: root.columnWidth
        // The hours fill up to ~60 % of the screen, at most the full 52 px an hour.
        hourHeight: Math.max(28, Math.min(52, Math.floor(root.screenHeight * 0.6 / (lastHour - firstHour))))
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
        visible: root.widgetsVisible
        anchors.top: true
        anchors.left: true
        margins.top: calendar.implicitHeight
        panelWidth: root.columnWidth - root.gap - root.habitsWidth
        panelHeight: root.lowerHeight
        room: ({
                left: root.edge,
                top: root.gap / 2,
                right: root.gap / 2,
                bottom: root.edge
            })
    }

    HabitTracker {
        id: habits
        visible: root.widgetsVisible
        anchors.top: true
        anchors.left: true
        margins.top: calendar.implicitHeight
        margins.left: todo.implicitWidth
        panelWidth: root.habitsWidth
        panelHeight: root.lowerHeight
        room: ({
                left: root.gap / 2,
                top: root.gap / 2,
                right: root.fade,
                bottom: root.edge
            })
        fade: root.fade
    }

    KittyCat {}

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

    // The terminal cats (KittyCat, Pet): `qs ipc call cat react error|ok|cheer|wake|pet` plays a reaction
    // on every cat, `reactPid <event> <pid>` only on the window of that process,
    // `mood <expression>` pins one (see ~/.config/cat/poses.json), `unpin` lets context decide again,
    // `tester` opens or closes CatTester, `kitty` hides or shows the cats, `sing` turns singing along to
// the audio off or on, `singOffset <ms>` shifts the mouths later (or earlier, negative) to match the sound.
    IpcHandler {
        target: "cat"

        function react(event: string): bool {
            return Pet.react(event);
        }
        // Only the cat on the window of process `pid` (the fish hook sends $KITTY_PID).
        function reactPid(event: string, pid: int): bool {
            return Pet.reactPid(event, pid);
        }
        // The fish hook: a command (`id`) in the window of `pid` started, then finished with `event`
        // ("none", or a reaction) — the cat strains, squished, in between.
        function busyPid(pid: int, id: string): bool {
            return Pet.busyPid(pid, id);
        }
        // An ssh/mosh session (`id`) in the window of `pid`: the cat is red with sunglasses until finishedPid.
        function remotePid(pid: int, id: string): bool {
            return Pet.remotePid(pid, id);
        }
        function finishedPid(pid: int, id: string, event: string): bool {
            return Pet.finishedPid(pid, id, event);
        }
        function mood(expression: string): void {
            Pet.pin(expression);
        }
        function unpin(): void {
            Pet.unpin();
        }
        function tester(): void {
            Pet.testerOpen = !Pet.testerOpen;
        }
        function kitty(): void {
            Pet.kittyShown = !Pet.kittyShown;
        }
        function sing(): bool {
            Pet.singAlong = !Pet.singAlong;
            return Pet.singAlong;
        }
        function singOffset(ms: int): void {
            Pet.singOffset = ms;
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

    LazyLoader {
        active: Pet.testerOpen
        CatTester {}
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
