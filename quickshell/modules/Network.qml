import QtQuick
import qs
import qs.components

// Wi-Fi / ethernet state from Net; click toggles Wi-Fi, right click opens iwgtk.
Module {
    readonly property var info: Net.info
    readonly property var wifiIcons: [0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928]

    text: {
        switch (info.state) {
        case "wifi":
            return Theme.g(Util.bucket(wifiIcons, info.signal)) + " " + Privacy.mask(info.ssid);
        case "ethernet":
            return Theme.g(0xef09);
        case "disabled":
            return Theme.g(0xf092e);
        case "disconnected":
            return Theme.g(0xf0923) + "  disconnected";
        default:
            return "";
        }
    }
    onClicked: Net.toggleWifi()
    onRightClicked: Util.run("iwgtk")
}
