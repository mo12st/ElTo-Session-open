// The dock's system area: the clock, a Settings entry that opens ElTo Control, and the status readouts
// the shell already has data for (volume from Pipewire, network from NetworkManager, battery from UPower).
// It composes the existing widgets from this directory instead of re-reading those services, so each
// readout keeps one source of truth. Text only, in the dock's serif: no new icon files.
// See DOCK-SYSTEM-AREA.md for what is wired to real data and what is not.
import Quickshell
import Quickshell.Io
import QtQuick

Row {
    id: root
    property int textSize: 14
    spacing: 12

    Volume { textColor: Theme.textMuted; pixelSize: root.textSize }
    Network { textColor: Theme.textMuted; pixelSize: root.textSize }
    Battery { textColor: Theme.textMuted; pixelSize: root.textSize }

    Rectangle { width: 1; height: 18; color: Theme.divider; anchors.verticalCenter: parent.verticalCenter }

    // Settings: ElTo Control, installed as `elto-control` by session/install.sh, with its desktop entry
    // as the preferred route and the plain command as the fallback.
    Rectangle {
        id: settings
        width: label.implicitWidth + 18; height: 24; radius: 12
        anchors.verticalCenter: parent.verticalCenter
        color: hit.containsMouse ? Theme.selection : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.ms(140) } }
        Text {
            id: label
            anchors.centerIn: parent
            text: "Settings"
            color: Theme.text
            font.family: Theme.serifItalic; font.italic: true; font.pixelSize: root.textSize
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: hit
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.openControl()
        }
    }

    Clock { textColor: Theme.text; pixelSize: root.textSize; format: "HH:mm" }

    Process { id: launcher }

    function openControl() {
        var e = DesktopEntries.byId("elto-control")
        if (e) { e.execute(); console.log("ELTODOCK open elto-control via desktop entry"); return }
        launcher.command = ["elto-control"]
        launcher.running = true
        console.log("ELTODOCK open elto-control via command")
    }
}
