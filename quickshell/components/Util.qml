pragma Singleton

import Quickshell

Singleton {
    // waybar's max-length: counts code points, cuts with an ellipsis.
    function truncate(str, max) {
        const chars = Array.from(str);
        return chars.length > max ? chars.slice(0, max - 1).join("") + "…" : str;
    }

    // waybar picks format-icons[i] by splitting 0-100 into equal buckets.
    function bucket(icons, percent) {
        const i = Math.floor(percent / (100 / icons.length));
        return icons[Math.max(0, Math.min(icons.length - 1, i))];
    }

    // Powers the wifi device (iwd, the same one scripts/network.sh reads) on or off.
    function wifiPowerCommand(on) {
        // The device iwd manages, not the first /sys/class/net/wl*: a stale second netdev can sit on the
        // dongle's radio (see scripts/network.sh). iwctl colors its output even when piped.
        const device = "iwctl device list | sed 's/\\x1b\\[[0-9;]*m//g' | awk '$2 ~ /^([0-9a-f]{2}:){5}/ {print $1; exit}'";
        return `iwctl device "$(${device})" set-property Powered ${on ? "on" : "off"}`;
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
}
