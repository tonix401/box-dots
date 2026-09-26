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

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
}
