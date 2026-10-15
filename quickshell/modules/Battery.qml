import QtQuick
import Quickshell.Io
import qs
import qs.components

// Hidden on machines without a battery.
Module {
    id: root

    property int capacity: -1
    property string status: ""
    property real hoursLeft: -1
    property real smoothedPower: 0
    property string smoothedStatus: ""
    // Per-sample EMA weight: ~1 min time constant at the 5s poll interval.
    readonly property real smoothing: 1 - Math.exp(-5 / 60)

    readonly property bool charging: status === "Charging" || status === "Full" || status === "Not charging"

    visible: capacity >= 0
    text: icon() + " " + capacity + "%"
    tooltip: {
        if (!(hoursLeft > 0))
            return status;
        const mins = Math.round(hoursLeft * 60);
        return status + " · " + Math.floor(mins / 60) + "h " + String(mins % 60).padStart(2, "0") + "m " + (status === "Charging" ? "to full" : "left");
    }
    onClicked: Util.run("kitty -e btop")
    onRightClicked: Util.run("kitty -e btop")

    function icon() {
        const step = Math.max(0, Math.min(9, Math.floor(capacity / 10)));
        // nf-md-battery_charging_{10..100} and nf-md-battery_{10..90}, battery
        const charge = [0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d, 0xf0089, 0xf089e, 0xf008a, 0xf008b, 0xf0085];
        const drain = [0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079];
        return Theme.g(charging ? charge[step] : capacity >= 95 ? 0xf0079 : drain[step]);
    }

    FileView {
        id: uevent
        path: "/sys/class/power_supply/BAT0/uevent"
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            uevent.reload();
            const text = uevent.text();
            const get = key => {
                const m = text.match(new RegExp("^POWER_SUPPLY_" + key + "=(.*)$", "m"));
                return m ? m[1] : null;
            };
            const cap = get("CAPACITY");
            root.capacity = cap === null ? -1 : Number(cap);
            root.status = get("STATUS") ?? "";
            const raw = Number(get("POWER_NOW")), now = Number(get("ENERGY_NOW")), full = Number(get("ENERGY_FULL"));
            // EMA of the power draw so the estimate doesn't jump with every load spike.
            // Reset when charging/discharging flips, since the old average no longer applies.
            if (!(raw > 0) || root.status !== root.smoothedStatus)
                root.smoothedPower = raw;
            else
                root.smoothedPower += root.smoothing * (raw - root.smoothedPower);
            root.smoothedStatus = root.status;
            const power = root.smoothedPower;
            if (power > 0 && root.status === "Discharging")
                root.hoursLeft = now / power;
            else if (power > 0 && root.status === "Charging")
                root.hoursLeft = (full - now) / power;
            else
                root.hoursLeft = -1;
        }
    }
}
