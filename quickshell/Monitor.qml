pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The monitor over DDC/CI (ddcutil), for the start menu sliders and the brightness keys.
//
// Brightness is one 0..1 level: the top part drives the backlight (VCP 0x10), the bottom `dimShare`
// darkens further with a click-through black overlay (shell.qml), since the backlight's 0 is still bright.
//
// Color temperature: this AOC ignores VCP 0x0C, so warmer temperatures scale the red/green/blue gains
// (0x16/0x18/0x1A) along the blackbody curve; 6500 K is the neutral gains. Writing gains switches the
// monitor to its "User 1" preset. We stay there: every preset keeps its own brightness and contrast,
// so switching back to the factory "6500 K" preset made the brightness jump (to its stored 0).
Singleton {
    id: root

    // ── brightness ──
    readonly property real dimShare: 0.25 // part of the range below backlight 0
    readonly property real maxDim: 0.75 // overlay opacity at level 0

    property real backlight: 0 // 0..1
    property real dim: 0 // overlay opacity

    readonly property real level: dim > 0 ? dimShare * (1 - dim / maxDim) : dimShare + (1 - dimShare) * backlight
    readonly property string label: dim > 0 ? `dim ${Math.round(dim / maxDim * 100)}%` : `${Math.round(backlight * 100)}%`

    function setLevel(l) {
        l = Math.round(Math.max(0, Math.min(1, l)) * 1000) / 1000; // key steps must land exactly back on dimShare
        if (l < dimShare) {
            dim = maxDim * (1 - l / dimShare);
            backlight = 0;
        } else {
            dim = 0;
            backlight = (l - dimShare) / (1 - dimShare);
        }
        queue("10", Math.round(backlight * maxBrightness));
    }

    // `percent` of the backlight range, e.g. 8 / -8 from the brightness keys
    function change(percent) {
        setLevel(level + percent / 100 * (1 - dimShare));
    }

    // ── color temperature ──
    readonly property int minTemperature: 3000
    readonly property int maxTemperature: 6500
    property int temperature: maxTemperature
    property var baseGains: [48, 42, 50] // the monitor's gains at neutral; replaced by the saved/read values

    // Tanner Helland's blackbody approximation, relative to 6500 K
    function blackbody(kelvin) {
        const t = kelvin / 100;
        const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
        const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        return [r, g, b].map(c => Math.max(0, Math.min(255, c)));
    }

    function setTemperature(kelvin) {
        temperature = Math.round(Math.max(minTemperature, Math.min(maxTemperature, kelvin)) / 100) * 100;
        saveState();
        const neutral = blackbody(6500), warm = blackbody(temperature);
        ["16", "18", "1a"].forEach((code, i) => queue(code, Math.round(baseGains[i] * warm[i] / neutral[i])));
    }

    // ── ddcutil ──
    property string bus: "" // i2c bus of the monitor, found by refresh()
    property int maxBrightness: 100
    readonly property bool available: bus !== ""

    // Values waiting to be written, by VCP code. While ddcutil is busy only the newest value per code
    // is kept; everything pending goes out in one call when the previous one returns.
    property var pendingValues: ({})
    property var written: ({}) // last value written/read per code, to skip no-op writes

    function queue(code, value) {
        if (!available)
            return;
        if (written[code] === value)
            delete pendingValues[code];
        else
            pendingValues[code] = value;
        if (!writer.running)
            flush();
    }

    function flush() {
        const codes = Object.keys(pendingValues);
        if (codes.length === 0)
            return;
        // Leaving another preset for "User 1" would load User 1's own brightness: send ours along.
        if (codes.some(c => ["16", "18", "1a"].includes(c)) && written["14"] !== 11 && !codes.includes("10")) {
            pendingValues["10"] = Math.round(backlight * maxBrightness);
            codes.push("10");
        }
        const args = [];
        for (const code of codes) {
            args.push(code, String(pendingValues[code]));
            written[code] = pendingValues[code];
        }
        // writing any gain switches the preset to "User 1"
        if (codes.some(c => c !== "10"))
            written["14"] = 11;
        pendingValues = {};
        writer.command = ["ddcutil", "--bus", bus, "--noverify", "setvcp"].concat(args);
        writer.running = true;
    }

    function refresh() {
        reader.running = true;
    }

    function saveState() {
        state.setText(JSON.stringify({
            temperature: temperature,
            baseGains: baseGains
        }) + "\n");
    }

    Component.onCompleted: refresh()

    Process {
        id: writer
        onExited: root.flush()
    }

    Process {
        id: reader
        // prints "<bus> <brightness> <max> <preset> <red> <green> <blue>"
        command: ["sh", "-c", `bus=$(ddcutil detect --terse 2>/dev/null | sed -n 's|.*/dev/i2c-\\([0-9]*\\).*|\\1|p' | head -1)
            [ -n "$bus" ] || exit 1
            v() { ddcutil --bus "$bus" getvcp "$1" --terse; }
            set -- $(v 10); b="$4 $5"
            set -- $(v 14); p=$((0$7)) # "VCP 14 CNC x00 x0b x00 x05": last byte is the preset
            set -- $(v 16); r=$4
            set -- $(v 18); g=$4
            set -- $(v 1a); echo "$bus $b $p $r $g $4"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/).map(Number);
                if (f.length < 7 || f.some(isNaN))
                    return;
                const [bus, cur, max, preset, r, g, b] = f;
                root.maxBrightness = max;
                root.written = {
                    "10": cur,
                    "14": preset,
                    "16": r,
                    "18": g,
                    "1a": b
                };
                if (root.dim === 0)
                    root.backlight = cur / max;
                // still in the factory preset: its gains are the neutral ones
                if (preset === 5) {
                    root.temperature = root.maxTemperature;
                    root.baseGains = [r, g, b];
                    root.saveState();
                }
                root.bus = String(bus);
            }
        }
    }

    FileView {
        id: state
        path: Quickshell.statePath("monitor.json")
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.temperature = s.temperature ?? root.maxTemperature;
                root.baseGains = s.baseGains ?? root.baseGains;
            } catch (e) {}
        }
    }
}
