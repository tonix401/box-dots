import QtQuick
import qs
import qs.components

Module {
    text: Theme.g(0xeb53) + " " + Tailscale.status
    onClicked: Tailscale.toggle()
}
