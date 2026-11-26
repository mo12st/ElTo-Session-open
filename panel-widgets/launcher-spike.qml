// CONCEPT / SPIKE, UNVERIFIED. Run: quickshell -p panel-widgets/launcher-spike.qml
// Open the launcher: quickshell -p panel-widgets/launcher-spike.qml ipc call launcher toggle
// (or click the Menu pill). Palette and motion tokens come from ElToPalette.
import Quickshell
import QtQuick

ShellRoot {
    LauncherWindow {
        id: launcher
    }

    PanelWindow {
        anchors {
            left: true
            bottom: true
        }
        implicitWidth: 120
        implicitHeight: 56
        color: ElToPalette.cream

        ElToPill {
            anchors.centerIn: parent
            label: "Menu"
            active: launcher.open
            onClicked: launcher.toggle()
        }
    }
}
