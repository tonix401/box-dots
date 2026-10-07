pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland

// What the cats on kitty windows (KittyCat) are feeling. A base mood from context, highest first: asleep after
// five minutes without input, vibing while music plays, sleepy at night, else neutral. Reactions win
// over it for a moment, either for every cat (`react(event)`) or only the cat of one window
// (`react(event, [address])`, `reactPid(event, pid)` for the window of a process): a command's result
// startles or cheers only the terminal it ran in. While a command runs (anything but interactive
// programs), the fish hook marks its window busy (`busyPid`), and that cat strains, squished flat,
// until `finishedPid`. `pin(expression)` holds an expression instead of the base mood until `unpin()`,
// still interrupted by reactions.
// Driven by the `cat` IPC target in shell.qml: the fish prompt reports failed and long commands,
// HabitTracker and TodoList cheer on check-ins. CatTester (`qs ipc call cat
// tester`) triggers all of it by hand, and can fake the context via `overrides`.
Singleton {
    id: root

    property string pinned: ""
    // Running reactions by target, "*" for every cat or a Hyprland window address:
    // {expression, event, until (ms since epoch)}. A reaction for every cat replaces all of them.
    property var running: ({})
    readonly property string reactionEvent: Object.values(running).map(r => r.event).join(", ")
    // Windows running a command: address -> [id] (one per fish command; splits in one kitty window
    // share it). `finished` remembers recent ids, so a `busy` arriving after its `finished` (both are
    // separate qs processes racing) is ignored instead of squishing for good.
    property var busy: ({})
    property var finished: []
    property bool squishAll: false // the tester's hold-to-squish
    property bool testerOpen: false
    property bool kittyShown: true // the small cats on kitty windows (KittyCat)

    // Context as measured, and as used: an override (true/false, for testing) replaces the measurement.
    property var overrides: ({}) // "idle" | "playing" | "night" -> bool
    readonly property var measured: ({
            idle: idle.isIdle,
            playing: Mpris.players.values.some(p => p.isPlaying),
            night: clock.hours >= 23 || clock.hours < 7
        })
    readonly property bool isIdle: overrides.idle ?? measured.idle
    readonly property bool playing: overrides.playing ?? measured.playing
    readonly property bool night: overrides.night ?? measured.night
    readonly property string base: isIdle ? "asleep" : playing ? "vibing" : night ? "sleepy" : "neutral"
    // What every cat shows unless a reaction of its own window runs; expressionFor() is one cat's.
    readonly property string expression: running["*"]?.expression || pinned || base

    function expressionFor(address) {
        return running[address]?.expression || running["*"]?.expression || (isBusy(address) ? "straining" : "") || pinned || base;
    }

    function isBusy(address) {
        return (busy[address]?.length ?? 0) > 0;
    }

    function squishedFor(address) {
        return squishAll || isBusy(address);
    }

    // A one-off motion, e.g. ("hop", 2), for the cats of `target` ("*" for all, else a window address).
    signal acted(string motion, int count, string target)

    readonly property var reactions: ({
            error: {
                expression: "startled",
                ms: 1500
            },
            ok: {
                expression: "happy",
                ms: 2000
            },
            cheer: {
                expression: "happy",
                ms: 3000,
                motion: "hop",
                count: 2
            },
            wake: {
                expression: "startled",
                ms: 1000
            },
            pet: {
                expression: "purr",
                ms: 2000
            },
            impressed: {
                expression: "impressed",
                ms: 3500
            }
        })

    // `targets`: window addresses to react in; omitted (or empty) for every cat.
    function react(event, targets) {
        const r = reactions[event];
        if (!r)
            return false;
        const entry = {
            expression: r.expression,
            event: event,
            until: Date.now() + r.ms
        };
        let next;
        if (!targets || targets.length === 0) {
            next = {
                "*": entry
            };
            targets = ["*"];
        } else {
            next = Object.assign({}, running);
            for (const t of targets)
                next[t] = entry;
        }
        running = next;
        if (r.motion)
            for (const t of targets)
                acted(r.motion, r.count ?? 1, t);
        return true;
    }

    // React in the window(s) of process `pid` (what fish sends: kitty's $KITTY_PID). Each kitty window
    // is its own process; if several windows share one, the focused one wins. False if none matches.
    function reactPid(event, pid) {
        const addresses = windowsOf(pid);
        return addresses.length > 0 && react(event, addresses);
    }

    function windowsOf(pid) {
        const windows = Hyprland.toplevels.values.filter(t => t.lastIpcObject?.pid === pid);
        const focused = windows.filter(t => t.activated);
        return (focused.length > 0 ? focused : windows).map(t => t.address);
    }

    // Mark (on) or unmark command `id` as running in window `address`.
    function setBusy(address, id, on) {
        const next = Object.assign({}, busy);
        const rest = (next[address] ?? []).filter(e => e !== id);
        if (on)
            rest.push(id);
        if (rest.length > 0)
            next[address] = rest;
        else
            delete next[address];
        busy = next;
    }

    // From the fish hook, as a command starts: squish the cat of its window until finishedPid(…, id, …).
    function busyPid(pid, id) {
        const addresses = windowsOf(pid);
        if (!finished.includes(id))
            for (const a of addresses)
                setBusy(a, id, true);
        return addresses.length > 0;
    }

    // From the fish hook, after a command: let go (the cat boings back) and play
    // `event`'s reaction ("none" for none).
    function finishedPid(pid, id, event) {
        finished = finished.concat([id]).slice(-50);
        for (const a in busy)
            if (busy[a].includes(id))
                setBusy(a, id, false);
        return event === "none" || reactPid(event, pid);
    }

    function pin(expression) {
        pinned = expression;
    }

    function act(motion, count) {
        acted(motion, count ?? 1, "*");
    }

    function squish(down) {
        squishAll = down;
    }

    // value: true/false to fake that context, undefined to measure it again.
    function override(key, value) {
        const o = Object.assign({}, overrides);
        if (value === undefined)
            delete o[key];
        else
            o[key] = value;
        overrides = o;
    }

    function unpin() {
        pinned = "";
    }

    // Ends reactions as their time runs out.
    Timer {
        interval: 100
        repeat: true
        running: Object.keys(root.running).length > 0
        onTriggered: {
            const now = Date.now(), next = {};
            for (const t in root.running)
                if (root.running[t].until > now)
                    next[t] = root.running[t];
            if (Object.keys(next).length !== Object.keys(root.running).length)
                root.running = next;
        }
    }

    onIsIdleChanged: if (!isIdle)
        react("wake")

    // Whatever the tester pinned or faked ends with it.
    onTesterOpenChanged: if (!testerOpen) {
        unpin();
        overrides = {};
        squish(false);
        for (const a in busy)
            if (busy[a].includes("tester"))
                setBusy(a, "tester", false);
    }

    IdleMonitor {
        id: idle
        timeout: 300
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
