pragma Singleton

import Quickshell

// Which rofi-replacement menu is open ("" = none). Driven by the `menu` IPC target in shell.qml.
Singleton {
    property string active: ""

    function open(name) {
        active = name;
    }

    function toggle(name) {
        active = active === name ? "" : name;
    }

    function close() {
        active = "";
    }
}
