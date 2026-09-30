pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Client for the dankcalendar daemon (dcal): newline-delimited JSON requests over its unix socket.
// The same connection subscribes to change notifications; each burst bumps `revision`.
Singleton {
    id: root

    property var calendars: []
    // The Google calendar HabitTracker.qml logs check-ins to; "" until one named "Habits" exists.
    readonly property string habitsCalendarId: calendars.find(c => c.name === "Habits" && !c.readOnly)?.id ?? ""
    property int revision: 0
    readonly property bool syncing: unsynced.length > 0
    property var unsynced: [] // accounts sync() is still waiting for
    readonly property bool connected: socket.item?.connected ?? false

    property var pending: ({})
    property int nextId: 1

    // `callback` gets the result; an error answer goes to `onError` (as a message) instead.
    // Returns false when the daemon isn't connected.
    function request(method, params, callback, onError) {
        const s = socket.item;
        if (!s?.connected)
            return false;
        const id = nextId++;
        pending[id] = {
            callback: callback,
            onError: onError
        };
        s.write(JSON.stringify({
            id: id,
            method: method,
            params: params
        }) + "\n");
        s.flush();
        return true;
    }

    function handle(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.event) {
            if (msg.event === "sync" && msg.data?.type !== "started")
                unsynced = unsynced.filter(id => id !== msg.data?.accountId);
            changed.restart();
            return;
        }
        const req = pending[msg.id];
        if (!req)
            return;
        delete pending[msg.id];
        if (!msg.error)
            req.callback?.(msg.result);
        else
            req.onError?.(typeof msg.error === "string" ? msg.error : msg.error.message ?? JSON.stringify(msg.error));
    }

    // Syncs every account with its server now. The daemon answers at once and reports each
    // account's sync as a "sync" event; `syncing` holds until all of them have.
    function sync() {
        if (syncing)
            return;
        request("accounts.list", {}, accounts => {
            root.unsynced = (accounts ?? []).map(a => a.id);
            syncTimeout.restart();
            root.request("accounts.refresh", {}, null, () => root.unsynced = []);
        });
    }

    function refresh() {
        request("calendars.list", {}, result => root.calendars = result ?? []);
        revision++;
    }

    // Syncs report changes in bursts.
    Timer {
        id: changed
        interval: 400
        onTriggered: root.refresh()
    }

    // In case an account never reports back.
    Timer {
        id: syncTimeout
        interval: 30000
        onTriggered: root.unsynced = []
    }

    // The socket is named after the daemon's pid, so it is looked up again on every (re)connect.
    Process {
        id: locate
        running: true
        command: ["sh", "-c", "ls -t \"$XDG_RUNTIME_DIR\"/dankcal-*.sock 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path === "") {
                    retry.restart();
                    return;
                }
                socket.path = path;
                socket.active = true;
            }
        }
    }

    // Tears the old socket down outside its own signal handlers, then dials again.
    Timer {
        id: retry
        interval: 5000
        onTriggered: {
            root.pending = {};
            socket.active = false;
            locate.running = true;
        }
    }

    // Quickshell's Socket can't redial after a failed attempt, so every attempt gets a fresh one.
    Loader {
        id: socket

        property string path

        active: false
        onLoaded: item.connected = true // dial once `item` is set: a unix connect can finish synchronously

        sourceComponent: Socket {
            path: socket.path
            parser: SplitParser {
                onRead: line => root.handle(line)
            }
            onConnectionStateChanged: {
                if (connected) {
                    root.request("subscribe", {
                        topics: ["calendars", "events", "sync", "tasks"] // "tasks" works though `dcal ipc list` doesn't name it
                    });
                    root.refresh();
                } else {
                    retry.restart();
                }
            }
            onError: retry.restart()
        }
    }
}
