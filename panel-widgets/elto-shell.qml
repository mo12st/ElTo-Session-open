// CONCEPT / SPIKE: the ElTo session shell in one Quickshell config: wallpaper, bottom panel, launcher, notifications.
// Run by session/elto-session: quickshell -p panel-widgets/elto-shell.qml
import Quickshell
import QtQuick

ShellRoot {
    Wallpaper {}
    AppDrawer { id: drawer }
    NotificationPopups {}
    Notch { drawer: drawer }

    Dock { drawer: drawer }
    PolkitDialog {}

    Component.onCompleted: Sound.play("session-start")
}
