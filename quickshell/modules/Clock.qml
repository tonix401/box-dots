import QtQuick
import Quickshell
import qs
import qs.components

// The calendar lives in CalendarDrawer; a click here pins it (see Bar.qml).
Module {
    text: Theme.g(0xf017) + " " + Qt.formatTime(clock.date, "HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
