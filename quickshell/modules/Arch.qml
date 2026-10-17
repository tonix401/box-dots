import QtQuick
import qs
import qs.components

Module {
    text: Theme.g(0xf313) + " " + Privacy.mask(who.output)
    onClicked: Menus.toggle("power")

    Poll {
        id: who
        command: ["sh", "-c", "echo \"$USER@$(cat /etc/hostname)\""]
    }
}
