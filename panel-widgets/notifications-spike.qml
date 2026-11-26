// CONCEPT / SPIKE, UNVERIFIED. Run: quickshell -p panel-widgets/notifications-spike.qml
// Test with: notify-send "ElTo" "hello" ; notify-send -u critical "ElTo critical" "stays until clicked"
import Quickshell
import QtQuick

ShellRoot {
    NotificationPopups {}
}
