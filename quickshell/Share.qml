pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen-share requests from xdg-desktop-portal-hyprland. Its picker (custom_picker_binary in
// hypr/xdph.conf) is hypr/scripts/share-picker.sh, which hands the request over with
// `qs ipc call share pick` and waits on a FIFO for one line: a selection in hyprland-share-picker's
// format (`[SELECTION]<flags>/screen:<output>`, `/window:<id>`, `/region:<output>@x,y,w,h`), or an
// empty line to cancel. The menu itself is menus/ShareMenu.qml.
Singleton {
    id: root

    property string reply: "" // FIFO the script reads; "" = no request pending
    property var windows: [] // {id, appClass, title, address}: address is the Hyprland one as 0x… hex
    property bool allowToken: false // `r` flag: the app gets a restore token and may skip the dialog next time
    property bool drawingRegion: false // slurp is running; the menu is closed but the request still pending

    readonly property bool pending: reply !== ""

    function request(fifo, list, allowToken) {
        answer(""); // a request still open is superseded
        root.windows = parse(list);
        root.allowToken = allowToken;
        root.reply = fifo;
        Menus.open("share");
    }

    // XDPH_WINDOW_SHARING_LIST: `<id>[HC>]<class>[HT>]<title>[HE>]<address>[HA>]` per window, address in decimal.
    function parse(list) {
        return list.split("[HA>]").filter(e => e.includes("[HC>]")).map(e => {
            const [id, rest] = e.split("[HC>]");
            const [appClass, rest2] = rest.split("[HT>]");
            const [title, address] = rest2.split("[HE>]");
            return {
                id: id,
                appClass: appClass,
                title: title,
                address: "0x" + Number(address).toString(16) // < 2^53, so exact
            };
        });
    }

    // `selection` without the prefix, e.g. "screen:HDMI-A-1"; "" cancels. Only the first answer counts.
    function answer(selection) {
        if (!pending)
            return;
        const line = selection === "" ? "" : `[SELECTION]${allowToken ? "r" : ""}/${selection}`;
        // detached: the menu may be destroyed right after; the timeout only matters if the script is gone
        Quickshell.execDetached(["timeout", "5", "sh", "-c", '[ -p "$2" ] && printf "%s\\n" "$1" > "$2"', "sh", line, reply]);
        reply = "";
        drawingRegion = false;
    }

    // Closes the menu while slurp runs; cancelling slurp brings the menu back.
    function drawRegion() {
        drawingRegion = true;
        Menus.close();
        slurp.running = true;
    }

    Process {
        id: slurp

        command: ["slurp", "-f", "%o %x %y %w %h"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^(\S+) (-?\d+) (-?\d+) (\d+) (\d+)$/);
                if (!m || !root.pending) {
                    root.drawingRegion = false;
                    if (root.pending)
                        Menus.open("share");
                    return;
                }
                // slurp gives layout coordinates; the portal wants them relative to the output
                const screen = Quickshell.screens.find(s => s.name === m[1]);
                const x = Number(m[2]) - (screen?.x ?? 0), y = Number(m[3]) - (screen?.y ?? 0);
                root.answer(`region:${m[1]}@${x},${y},${m[4]},${m[5]}`);
            }
        }
    }
}
