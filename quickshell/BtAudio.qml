pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth audio profiles per device: Hi-Fi (A2DP) or call mode (HSP/HFP, mono 16 kHz, sounds hollow).
// WirePlumber flips a headset into call mode when an app opens its mic, and doesn't always flip it back.
// Follows `pactl subscribe` and re-reads the bluez cards on every card event.
Singleton {
    id: root

    property var cards: ({}) // address "AA:BB:…" -> { name, active, hifi, call }

    function card(address) {
        return cards[address] ?? null;
    }

    function isCall(address) {
        return card(address)?.active.startsWith("headset") ?? false;
    }

    // The highest-priority A2DP / HFP profile, so Hi-Fi picks aptX or AAC over SBC.
    function setCall(address, call) {
        const c = card(address);
        const profile = c && (call ? c.call : c.hifi);
        if (profile)
            Quickshell.execDetached(["pactl", "set-card-profile", c.name, profile]);
    }

    Process {
        id: list
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cards = {};
                for (const c of JSON.parse(text || "[]")) {
                    if (!c.name.startsWith("bluez_card."))
                        continue;
                    const best = prefix => Object.entries(c.profiles).filter(([n, p]) => n.startsWith(prefix) && p.available).sort((a, b) => b[1].priority - a[1].priority)[0]?.[0] ?? "";
                    cards[c.name.slice(11).replace(/_/g, ":")] = {
                        name: c.name,
                        active: c.active_profile,
                        hifi: best("a2dp"),
                        call: best("headset")
                    };
                }
                root.cards = cards;
            }
        }
    }

    Process {
        id: watch
        command: ["pactl", "subscribe"]
        running: true
        onStarted: list.running = true
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(" on card "))
                    list.running = true;
            }
        }
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: watch.running = true
    }
}
