import QtQuick
import qs
import qs.components

Module {
    text: Theme.g(0xf08c7) + " " + Privacy.mask(who.output)
    onClicked: Menus.toggle("power")

    Poll {
        id: who
        command: ["sh", "-c", "echo \"$USER@$(cat /etc/hostname)\""]
    }
}
