// CONCEPT / SPIKE: the ElTo session shell in one Quickshell config: wallpaper, bottom panel, launcher, notifications.
// Run by session/elto-session: quickshell -p panel-widgets/elto-shell.qml
import Quickshell
import QtQuick

ShellRoot {
    Wallpaper {}
    LauncherWindow {
        id: launcher
    }
    NotificationPopups {}

    PanelWindow {
        anchors {
            left: true
            right: true
            bottom: true
        }
        implicitHeight: 56
        color: ElToPalette.cream

        ElToPill {
            id: menu
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            label: "Menu"
            active: launcher.open
            onClicked: launcher.toggle()
        }

        TaskbarPills {
            anchors.left: menu.right
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: Math.min(contentWidth, parent.width - 600)
        }

        Panel {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
