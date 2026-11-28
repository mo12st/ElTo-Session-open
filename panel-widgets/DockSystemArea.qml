// The dock's system area: the clock, a Settings entry that opens ElTo Control, and the status readouts
// the shell already has data for (volume from Pipewire, network from NetworkManager, battery from UPower).
// It composes the existing widgets from this directory instead of re-reading those services, so each
// readout keeps one source of truth. Text only, in the dock's serif: no new icon files.
// trayStyle, clockStyle and clockPosition come from the dock theme and are optional: "text" and "end" draw
// exactly what this file drew before those tokens existed.
// See DOCK-SYSTEM-AREA.md for what is wired to real data and what is not.
import Quickshell
import Quickshell.Io
import QtQuick

Row {
    id: root
    property int textSize: 14
    property string trayStyle: "text"     // text | compact | none
    property string clockStyle: "text"    // text | pill | none
    property string clockPosition: "end"  // end: drawn here; start: drawn at the dock's leading edge
    readonly property int readoutSize: root.trayStyle === "compact" ? Math.max(10, root.textSize - 3) : root.textSize
    spacing: root.trayStyle === "compact" ? 8 : 12

    Volume { visible: root.trayStyle !== "none"; textColor: Theme.textMuted; pixelSize: root.readoutSize }
    Network { visible: root.trayStyle !== "none"; textColor: Theme.textMuted; pixelSize: root.readoutSize }
    Battery { visible: root.trayStyle !== "none"; textColor: Theme.textMuted; pixelSize: root.readoutSize }

    Rectangle { visible: root.trayStyle === "text"; width: 1; height: 18; color: Theme.divider; anchors.verticalCenter: parent.verticalCenter }

    // Settings: ElTo Control, installed as `elto-control` by session/install.sh, with its desktop entry
    // as the preferred route and the plain command as the fallback.
    Rectangle {
        id: settings
        visible: root.trayStyle === "text"
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

    // clock: plain text by default, a pill on request, hidden here when the world puts it at the start
    Clock {
        visible: root.clockStyle === "text" && root.clockPosition !== "start"
        textColor: Theme.text; pixelSize: root.textSize; format: "HH:mm"
    }
    Rectangle {
        visible: root.clockStyle === "pill" && root.clockPosition !== "start"
        width: pillClock.implicitWidth + 18; height: 22; radius: 11
        color: Theme.selection
        anchors.verticalCenter: parent.verticalCenter
        Clock {
            id: pillClock
            anchors.centerIn: parent
            textColor: Theme.text; pixelSize: Math.max(10, root.textSize - 1); format: "HH:mm"
        }
    }

    Process { id: launcher }

    function openControl() {
        var e = DesktopEntries.byId("elto-control")
        if (e) { e.execute(); console.log("ELTODOCK open elto-control via desktop entry"); return }
        launcher.command = ["elto-control"]
        launcher.running = true
        console.log("ELTODOCK open elto-control via command")
    }
}
