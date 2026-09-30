pragma Singleton

import Quickshell
import Quickshell.Io

// Whether the desktop widgets (calendar, todo list, habit tracker) are shown. Driven by the
// `widgets` IPC target in shell.qml; remembered across restarts.
Singleton {
    id: root

    property bool widgetsShown: true

    function setShown(shown) {
        widgetsShown = shown;
        state.setText(JSON.stringify({
            widgetsShown: shown
        }) + "\n");
    }

    function toggle() {
        setShown(!widgetsShown);
    }

    FileView {
        id: state
        path: Quickshell.statePath("desktop.json")
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                root.widgetsShown = JSON.parse(text()).widgetsShown ?? true;
            } catch (e) {}
        }
    }
}
