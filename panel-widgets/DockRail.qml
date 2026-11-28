// The dock "Rail" variant: a narrow vertical rail down the left (or right) edge, the shape the aero
// Habitat concept draws. Same model as the other variants (pinned apps, open windows, pin/unpin menu),
// laid out as a column instead of a row: launcher at the top, pinned tiles, a divider, one tile per open
// window, and the workspace indicator plus the clock at the bottom, which is where the concept art puts
// them. Every look value comes from the same dock theme section; only railWidth is new.
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
    property var menu: null   // { y, id, pinned }

    // the variant this file draws; Dock.qml loads it only for this id, the check is the second lock
    readonly property string style: "rail-dock"
    // the rail lives on a side edge; a world that asks for bottom or top with this variant gets the left
    readonly property bool onRight: win.dock.look.edge === "right"
    // room beside the strip for the right-click menu (menu width 130 + 8 gap)
    readonly property int menuRoom: 138
    readonly property real barAlpha: (dk.glass || win.dock.look.material === "glass") ? dk.opacity : 1

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "elto-dock"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: !win.onRight; right: win.onRight; top: true; bottom: true }
    implicitWidth: win.dock.look.railWidth + win.menuRoom
    implicitHeight: win.screen ? win.screen.height : 800
    color: "transparent"
    mask: Region { item: bar; regions: [ Region { item: menuBox } ] }
    visible: win.dock.style === win.style

    // click anywhere else closes the menu
    MouseArea { anchors.fill: parent; enabled: win.menu !== null; onClicked: win.menu = null }

    Rectangle {
        id: bar
        readonly property string mat: win.dock.look.material
        width: win.dock.look.railWidth
        height: parent.height
        x: win.onRight ? parent.width - width : 0
        radius: win.dock.look.radius > 0 ? Math.min(win.dock.look.radius, width / 2) : 0
        color: Qt.alpha(Theme.role(win.dk.color), win.barAlpha)
        border.width: bar.mat === "glass" ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.45)
        Behavior on color { ColorAnimation { duration: Theme.ms(200) } }

        // 95-style bevel: light on the top and the inner side, dark on the bottom and the outer side
        Rectangle {
            visible: bar.mat === "bevel"
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 2
            color: Qt.rgba(1, 1, 1, 0.7)
        }
        Rectangle {
            visible: bar.mat === "bevel"
            anchors { top: parent.top; bottom: parent.bottom }
            width: 2
            x: win.onRight ? parent.width - width : 0
            color: Qt.rgba(1, 1, 1, 0.7)
        }
        Rectangle {
            visible: bar.mat === "bevel"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
            color: Qt.rgba(0, 0, 0, 0.35)
        }
        Rectangle {
            visible: bar.mat === "bevel"
            anchors { top: parent.top; bottom: parent.bottom }
            width: 2
            x: win.onRight ? 0 : parent.width - width
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        // material: gloss adds a highlight band down the inner side
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: bar.mat === "gloss"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.43; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }

        // ---- launcher, pinned apps, open windows, from the top down
        Column {
            id: topCol
            width: parent.width
            y: win.dk.pad
            spacing: win.dk.gap

            // launcher: the world's logo when it has one, otherwise a mark; opens the app drawer
            Item {
                id: launch
                width: win.dk.tile; height: win.dk.tile
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: win.dock.look.button === "circle" ? width / 2 : (win.dock.look.button === "rounded" ? 10 : 0)
                    color: launchHit.containsMouse ? Theme.selection : "transparent"
                    border.width: win.dock.look.material === "bevel" ? 1 : 0
                    border.color: Theme.divider
                }
                property bool logoReady: logoImg.status === Image.Ready
                Image {
                    id: logoImg
                    visible: win.dock.look.launcherMark === "logo" && launch.logoReady
                    anchors.centerIn: parent
                    source: win.dock.logoSource()
                    sourceSize.width: win.dock.look.launcherLogoSize * 2
                    sourceSize.height: win.dock.look.launcherLogoSize * 2
                    width: win.dock.look.launcherLogoSize; height: win.dock.look.launcherLogoSize
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Rectangle {
                    visible: !(win.dock.look.launcherMark === "logo" && launch.logoReady)
                    width: 8; height: 8; radius: 4
                    anchors.centerIn: parent
                    color: Theme.accent
                }
                MouseArea {
                    id: launchHit
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (win.dock.drawer) win.dock.drawer.toggle()
                }
            }

            Repeater {
                model: win.dock.pinnedItems
                Item {
                    id: app
                    required property var modelData
                    readonly property bool running: win.dock.openApps[modelData.id] === true || win.dock.openApps[modelData.entry.startupClass] === true
                    width: win.dk.tile; height: win.dk.tile
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: win.dock.look.button === "circle" ? width / 2 : (win.dock.look.button === "rounded" ? 10 : 0)
                        color: Theme.selection
                        opacity: (win.dock.look.activeIndicator === "pill" && app.running) ? 1 : (am.containsMouse ? 0.6 : 0)
                        Behavior on opacity { NumberAnimation { duration: Theme.ms(140) } }
                    }
                    Rectangle {
                        visible: win.dock.look.activeIndicator === "dot" && app.running
                        width: 4; height: 4; radius: 2; color: Theme.accent
                        x: win.onRight ? 1 : parent.width - 5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        visible: win.dock.look.activeIndicator === "bar" && app.running
                        width: 2; height: 14; radius: 1; color: Theme.accent
                        x: win.onRight ? 1 : parent.width - 3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    LIcon { visible: app.modelData.glyph !== ""; anchors.centerIn: parent; name: app.modelData.glyph; size: win.dk.icon; tint: Theme.text; dir: win.dock.glyphDir; tintArt: win.dock.glyphTint
                        scale: am.pressed ? 0.92 : (am.containsMouse && Theme.motion ? 1.08 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } } }
                    IconImage { visible: app.modelData.glyph === ""; anchors.centerIn: parent; implicitSize: win.dk.icon
                        source: Quickshell.iconPath(app.modelData.entry.icon, "application-x-executable") }
                    MouseArea {
                        id: am; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton) win.menu = { y: app.mapToItem(null, 0, app.height / 2).y, id: app.modelData.id, pinned: true }
                            else { win.menu = null; app.modelData.entry.execute() }
                        }
                    }
                }
            }

            Rectangle {
                visible: win.dock.wl !== null && win.dock.wl.model.count > 0 && win.dock.pinnedItems.length > 0
                width: win.dk.tile * 0.7; height: 1
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.divider
            }

            Repeater {
                model: win.dock.wl ? win.dock.wl.model : null
                Item {
                    id: task
                    required property string uuid
                    required property string title
                    required property string appid
                    required property bool isActive
                    width: win.dk.tile; height: win.dk.tile
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property string appIcon: {
                        var e = win.dock.entryFor(task.appid)
                        return Quickshell.iconPath(e && e.icon ? e.icon : task.appid, "application-x-executable")
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: win.dock.look.button === "circle" ? width / 2 : (win.dock.look.button === "rounded" ? 10 : 0)
                        color: isActive ? Theme.selection : (tm.containsMouse ? Theme.surfaceAlt : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
                    }
                    IconImage { anchors.centerIn: parent; implicitSize: 18; source: task.appIcon }
                    Rectangle {
                        visible: win.dock.look.activeIndicator === "bar" && isActive
                        width: 2; height: 14; radius: 1; color: Theme.accent
                        x: win.onRight ? 1 : parent.width - 3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MouseArea {
                        id: tm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton) {
                                var e = win.dock.entryFor(task.appid)
                                if (e) win.menu = { y: task.mapToItem(null, 0, task.height / 2).y, id: e.id, pinned: win.dock.isPinned(e.id) }
                            } else { win.menu = null; win.dock.wl.activate(task.uuid) }
                        }
                    }
                }
            }
        }

        // ---- workspace indicator and clock, at the bottom as the concept draws them
        Column {
            id: botCol
            width: parent.width
            anchors.bottom: parent.bottom
            anchors.bottomMargin: win.dk.pad
            spacing: win.dk.gap

            DockPager {
                style: win.dock.look.workspaceStyle === "numbers" ? "dots" : win.dock.look.workspaceStyle
                count: win.dock.desktops ? win.dock.desktops.count : 0
                index: win.dock.desktops ? win.dock.desktops.currentIndex : -1
                name: win.dock.desktops ? win.dock.desktops.currentName : ""
                textSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
                onPick: i => { if (win.dock.desktops) win.dock.desktops.switchTo(i) }
            }
            Clock {
                visible: win.dock.look.clockStyle !== "none"
                anchors.horizontalCenter: parent.horizontalCenter
                textColor: Theme.text
                pixelSize: 11
                format: "HH:mm"
            }
        }
    }

    // right-click menu: one entry, Pin to dock or Unpin, opened beside the rail
    Rectangle {
        id: menuBox
        visible: win.menu !== null
        width: 130; height: 36; radius: 18
        x: win.onRight ? bar.x - width - 8 : bar.x + bar.width + 8
        y: win.menu ? Math.max(4, Math.min(win.height - height - 4, win.menu.y - height / 2)) : 0
        color: Theme.surface; border.width: 1; border.color: Theme.divider
        Text { anchors.centerIn: parent; text: win.menu && win.menu.pinned ? "Unpin" : "Pin to dock"
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 15; renderType: Text.NativeRendering }
        MouseArea {
            anchors.fill: parent
            onClicked: { if (win.menu.pinned) win.dock.unpin(win.menu.id); else win.dock.pin(win.menu.id); win.menu = null }
        }
    }
}
