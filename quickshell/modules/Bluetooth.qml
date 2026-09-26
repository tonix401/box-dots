import QtQuick
import Quickshell.Bluetooth
import qs
import qs.components

Module {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var connected: adapter ? adapter.devices.values.filter(d => d.connected) : []

    visible: adapter !== null
    text: {
        if (!adapter || !adapter.enabled)
            return Theme.g(0xf00b2) + " disabled";
        return connected.length > 0 ? Theme.g(0xf00b1) + " connected" : Theme.g(0xf00af) + " enabled";
    }
    tooltip: {
        if (!adapter)
            return "";
        if (connected.length === 0)
            return `${adapter.name} ${adapter.enabled ? "on" : "off"}`;
        const lines = connected.map(d => d.batteryAvailable ? `${Theme.g(0xf00b1)}  ${d.name} (${Math.round(d.battery * 100)}%)` : d.name);
        return `${Theme.g(0xf043b)}  ${connected.length} Connected:\n${lines.join("\n")}`;
    }
    onClicked: Util.run("rfkill toggle bluetooth")
    onRightClicked: Util.run("blueman-manager")
}
