// The dock's optional second surface: a thin strip along the top edge with the launcher, one button per
// open window, and the system area (status readouts, workspace indicator, clock) at the right. The two
// concepts that put a Start/Programs strip above the desktop show exactly these pieces and nothing else,
// so nothing else is drawn here: no application menu, no notification area beyond the readouts the dock
// already has. The app menu belongs to the panel lane.
// Dock.qml loads this only when the world sets dock.secondSurface to "top"; the dock below keeps its own
// edge, so a world that omits the key draws exactly what it drew before.
// CONCEPT until VM-verified by the implementer.
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win
    required property var dock
    readonly property var dk: Theme.dockT
    readonly property alias bar: bar
    readonly property real barAlpha: (dk.glass || win.dock.look.material === "glass") ? dk.opacity : 1

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "elto-dock-strip"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true }
    implicitHeight: win.dock.look.stripHeight
    color: "transparent"
    mask: Region { item: bar }
    // one log line, so the dock smoke can prove the second surface really loaded
    Component.onCompleted: console.log("ELTODOCK strip")

    Rectangle {
        id: bar
        readonly property string mat: win.dock.look.material
        width: parent.width
        height: win.dock.look.stripHeight
        color: Qt.alpha(Theme.role(win.dk.color), win.barAlpha)
        border.width: bar.mat === "glass" ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.45)

        // one hairline on the inner (bottom) edge, the way the concept strips close themselves
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: win.dk.glass ? Qt.rgba(1, 1, 1, 0.5) : Theme.divider
        }

        Row {
            id: leftRow
            x: win.dk.pad + 2
            height: parent.height
            spacing: win.dk.gap

            // launcher: label, or the world's own logo, plus a caret; opens the app drawer
            Rectangle {
                id: launch
                width: launchRow.implicitWidth + 18
                height: 24
                radius: win.dock.look.button === "circle" ? height / 2 : (win.dock.look.button === "rounded" ? 7 : 0)
                color: launchHit.containsMouse ? Theme.selection : "transparent"
                border.width: win.dock.look.material === "bevel" ? 1 : 0
                border.color: Theme.divider
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: launchRow
                    anchors.centerIn: parent
                    spacing: 5
                    property bool logoReady: launchLogo.status === Image.Ready
                    Image {
                        id: launchLogo
                        visible: win.dock.look.launcherMark === "logo" && launchRow.logoReady
                        source: win.dock.look.launcherMark === "logo" ? win.dock.logoSource() : ""
                        sourceSize.width: 40
                        sourceSize.height: 40
                        width: 16; height: 16
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: win.dock.look.launcherMark === "label" || win.dock.look.launcherMark === "button" || (win.dock.look.launcherMark === "logo" && win.dock.look.launcherLabel !== "")
                        text: win.dock.look.launcherLabel
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }
                    LIcon { name: "chevron-down"; size: 9; tint: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: launchHit
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (win.dock.drawer) win.dock.drawer.toggle()
                }
            }

            Rectangle { width: 1; height: parent.height * 0.5; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }

            // one button per open window, the shape the world's taskStyle asks for
            Repeater {
                model: win.dock.wl ? win.dock.wl.model : null
                Rectangle {
                    id: task
                    required property string uuid
                    required property string title
                    required property string appid
                    required property bool isActive
                    readonly property string appIcon: {
                        var e = win.dock.entryFor(task.appid)
                        return Quickshell.iconPath(e && e.icon ? e.icon : task.appid, "application-x-executable")
                    }
                    readonly property bool withIcon: win.dock.look.taskStyle !== "label"
                    width: Math.min(win.dk.pillWidth, taskRow.implicitWidth + 18)
                    height: 24
                    radius: win.dock.look.button === "circle" ? height / 2 : (win.dock.look.button === "rounded" ? 7 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    color: isActive ? Theme.selection : (tm.containsMouse ? Theme.surfaceAlt : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
                    Row {
                        id: taskRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconImage { visible: task.withIcon; implicitSize: 14; anchors.verticalCenter: parent.verticalCenter; source: task.appIcon }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, win.dk.pillWidth - 44)
                            elide: Text.ElideRight
                            text: task.title !== "" ? task.title : task.appid
                            color: Theme.text
                            font.family: Theme.sans
                            font.bold: isActive
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }
                    }
                    MouseArea {
                        id: tm
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: win.dock.wl.activate(task.uuid)
                    }
                }
            }
        }

        DockSystemArea {
            id: sys
            textSize: 12
            trayStyle: win.dock.look.trayStyle === "text" ? "compact" : win.dock.look.trayStyle
            clockStyle: win.dock.look.clockStyle
            clockPosition: "end"
            workspaceStyle: win.dock.look.workspaceStyle
            workspaceCount: win.dock.desktops ? win.dock.desktops.count : 0
            workspaceIndex: win.dock.desktops ? win.dock.desktops.currentIndex : -1
            workspaceName: win.dock.desktops ? win.dock.desktops.currentName : ""
            anchors { right: parent.right; rightMargin: win.dk.pad; verticalCenter: parent.verticalCenter }
            onPickWorkspace: i => { if (win.dock.desktops) win.dock.desktops.switchTo(i) }
        }
    }
}
