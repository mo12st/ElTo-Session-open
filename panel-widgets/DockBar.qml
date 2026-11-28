// The dock "Bar" variant: one full-width strip pinned to the bottom edge of the screen.
// Same contents and behavior as the island (pinned apps, one pill per open window, same right-click
// menu), with no floating margin and no island rounding; painterly paper with a hairline top edge.
// Every look value comes from the same Theme dock section, so a world needs no second dock block; the
// logic (pinned list, open windows, pin/unpin, activate) stays in Dock.qml and this file only draws it.
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
    property var menu: null   // { x, id, pinned }

    // the variant this file draws; Dock.qml loads it only for this id, the check is the second lock
    readonly property string style: "bar"
    // room above the strip for the right-click menu (menu height 36 + 8 gap)
    readonly property int menuRoom: 44
    readonly property real barAlpha: (dk.glass || win.dock.look.material === "glass") ? dk.opacity : 1

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "elto-dock"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; bottom: win.dock.look.edge === "bottom"; top: win.dock.look.edge === "top" }
    implicitHeight: win.dock.look.height + win.menuRoom
    color: "transparent"
    mask: Region { item: bar; regions: [ Region { item: menuBox } ] }
    visible: win.dock.style === win.style

    // click anywhere else closes the menu
    MouseArea { anchors.fill: parent; enabled: win.menu !== null; onClicked: win.menu = null }

    Rectangle {
        id: bar
        readonly property string mat: win.dock.look.material
        width: parent.width
        height: win.dock.look.height
        y: win.dock.look.edge === "bottom" ? parent.height - height : 0
        color: Qt.alpha(Theme.role(win.dk.color), win.barAlpha)
        border.width: bar.mat === "glass" ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.45)
        Behavior on color { ColorAnimation { duration: Theme.ms(200) } }

        // 95-style bevel: light on the top and left, dark on the bottom and right
        Rectangle {
            visible: bar.mat === "bevel"
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 2
            color: Qt.rgba(1, 1, 1, 0.7)
        }
        Rectangle {
            visible: bar.mat === "bevel"
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 2
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
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 2
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        // material: gloss adds a highlight band over the flat fill
        Rectangle {
            anchors.fill: parent
            visible: bar.mat === "gloss"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.43; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }

        // painterly edge: one hairline on the inner side, then a soft inner shade instead of a hard drop shadow
        Rectangle {
            anchors { top: win.dock.look.edge === "bottom" ? parent.top : undefined; bottom: win.dock.look.edge === "bottom" ? undefined : parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: win.dk.glass ? Qt.rgba(1, 1, 1, 0.5) : Theme.divider
        }
        Rectangle {
            anchors { top: win.dock.look.edge === "bottom" ? parent.top : undefined; bottom: win.dock.look.edge === "bottom" ? undefined : parent.bottom; left: parent.left; right: parent.right }
            height: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, Theme.shadowAlpha / 8) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ---- pinned apps, left
        Row {
            id: pinned
            x: win.dk.pad + 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: win.dk.gap

            // launcher mark: optional leading mark for a world's identity, absent by default
            Rectangle {
                visible: win.dock.look.launcherMark === "dot"
                width: 8; height: 8; radius: 4
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: win.dock.look.launcherMark === "label"
                text: win.dock.look.launcherLabel
                color: Theme.text
                font.family: Theme.serif; font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
            }
            // launcher button: label, or a per-world logo, plus a caret; opens the app drawer
            Rectangle {
                id: launch
                visible: win.dock.look.launcherMark === "button" || win.dock.look.launcherMark === "logo"
                width: launchRow.implicitWidth + 22
                height: 30
                radius: win.dock.look.button === "circle" ? height / 2 : (win.dock.look.button === "rounded" ? 7 : 0)
                color: launchHit.containsMouse ? Theme.selection : (win.dock.look.material === "bevel" ? Theme.surfaceAlt : "transparent")
                border.width: win.dock.look.material === "bevel" ? 1 : 0
                border.color: Theme.divider
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: launchRow
                    anchors.centerIn: parent
                    spacing: 6
                    // the world's own logo, drawn as art and never tinted; a missing file falls back to the label
                    Image {
                        visible: win.dock.look.launcherMark === "logo" && status === Image.Ready
                        source: win.dock.logoSource()
                        sourceSize.width: win.dock.look.launcherLogoSize * 2
                        sourceSize.height: win.dock.look.launcherLogoSize * 2
                        width: win.dock.look.launcherLogoSize; height: win.dock.look.launcherLogoSize
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: win.dock.look.launcherMark === "button"
                                 || (win.dock.look.launcherMark === "logo" && win.dock.look.launcherLabel !== "")
                        text: win.dock.look.launcherLabel
                        color: Theme.text
                        font.family: Theme.sans; font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }
                    LIcon { name: "chevron-down"; size: 10; tint: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: launchHit
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (win.dock.drawer) win.dock.drawer.toggle()
                }
            }
            Clock {
                visible: win.dock.look.clockStyle !== "none" && win.dock.look.clockPosition === "start"
                textColor: Theme.text; pixelSize: 13; format: "HH:mm"
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: win.dock.pinnedItems
                Item {
                    id: app
                    required property var modelData
                    readonly property bool running: win.dock.openApps[modelData.id] === true || win.dock.openApps[modelData.entry.startupClass] === true
                    width: win.dk.tile; height: win.dk.tile
                    // hover halo; the running state is drawn by the indicator the theme chooses
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
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.dock.look.edge === "bottom" ? parent.height + 1 : -5
                    }
                    Rectangle {
                        visible: win.dock.look.activeIndicator === "bar" && app.running
                        width: 14; height: 2; radius: 1; color: Theme.accent
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.dock.look.edge === "bottom" ? parent.height + 2 : -4
                    }
                    LIcon { visible: app.modelData.glyph !== ""; anchors.centerIn: parent; name: app.modelData.glyph; size: win.dk.icon; tint: Theme.text; dir: win.dock.glyphDir; tintArt: win.dock.glyphTint
                        scale: am.pressed ? 0.92 : (am.containsMouse && Theme.motion ? 1.08 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } } }
                    IconImage { visible: app.modelData.glyph === ""; anchors.centerIn: parent; implicitSize: win.dk.icon
                        source: Quickshell.iconPath(app.modelData.entry.icon, "application-x-executable") }
                    MouseArea {
                        id: am; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton) win.menu = { x: app.mapToItem(null, app.width / 2, 0).x, id: app.modelData.id, pinned: true }
                            else { win.menu = null; app.modelData.entry.execute() }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: split
            visible: win.dock.wl !== null && win.dock.wl.model.count > 0 && win.dock.pinnedItems.length > 0
            x: pinned.x + pinned.width + win.dk.gap
            width: 1; height: win.dk.tile * 0.7
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
        }

        // ---- open windows, one pill each, clipped so a long list never runs under the snail mark
        Item {
            id: pillsArea
            x: (split.visible ? split.x + 2 + win.dk.gap : pinned.x + pinned.width + win.dk.gap)
            anchors.verticalCenter: parent.verticalCenter
            height: win.dk.pillHeight
            // the system area owns the right end, so the pills stop before it
            width: Math.max(0, bar.width - win.dk.pad - x - (sys.width + 22))
            clip: true

            Row {
                id: pillRow
                spacing: win.dk.gap
                Repeater {
                    model: win.dock.wl ? win.dock.wl.model : null
                    Rectangle {
                        id: wp
                        required property string uuid
                        required property string title
                        required property string appid
                        required property bool isActive
                        readonly property bool flatTask: win.dock.look.taskStyle !== "pill"
                        readonly property string appIcon: {
                            var e = win.dock.entryFor(wp.appid)
                            return Quickshell.iconPath(e && e.icon ? e.icon : wp.appid, "application-x-executable")
                        }
                        width: flatTask ? Math.min(win.dk.pillWidth, taskRow.implicitWidth + 22) : win.dk.pillWidth
                        height: win.dk.pillHeight
                        radius: win.dock.look.button === "circle" ? height / 2 : (win.dock.look.button === "rounded" ? 8 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        color: (win.dock.look.taskStyle === "pill" && isActive) ? Theme.selection : (pm.containsMouse ? Theme.surfaceAlt : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
                        opacity: 0
                        Component.onCompleted: opacity = 1
                        Behavior on opacity { NumberAnimation { duration: Theme.ms(180) } }
                        Row {
                            id: taskRow
                            anchors.centerIn: parent; spacing: 8
                            LIcon { visible: win.dock.look.taskStyle === "pill"; name: "panel-top"; size: 16; tint: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            IconImage { visible: win.dock.look.taskStyle === "button"; implicitSize: 16; anchors.verticalCenter: parent.verticalCenter; source: wp.appIcon }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, win.dk.pillWidth - 46); elide: Text.ElideRight
                                text: wp.title !== "" ? wp.title : wp.appid
                                color: Theme.text
                                font.family: win.dock.look.taskStyle === "pill" ? Theme.serif : Theme.sans
                                font.italic: win.dock.look.taskStyle === "pill"
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }
                        }
                        MouseArea {
                            id: pm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: m => {
                                if (m.button === Qt.RightButton) {
                                    var e = win.dock.entryFor(wp.appid)
                                    if (e) win.menu = { x: wp.mapToItem(null, wp.width / 2, 0).x, id: e.id, pinned: win.dock.isPinned(e.id) }
                                } else { win.menu = null; win.dock.wl.activate(wp.uuid) }
                            }
                        }
                    }
                }
            }
        }

        // ---- system area, right end: clock, Settings, status readouts (same component as the island)
        Rectangle {
            id: sysDivider
            x: sys.x - 14
            width: 1; height: win.dk.tile * 0.7
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
        }

        DockSystemArea {
            id: sys
            textSize: 13
            trayStyle: win.dock.look.trayStyle
            clockStyle: win.dock.look.clockStyle
            clockPosition: win.dock.look.clockPosition
            anchors { right: parent.right; rightMargin: win.dk.pad; verticalCenter: parent.verticalCenter }
        }
    }

    // right-click menu: one entry, Pin to dock or Unpin (same menu as the island)
    Rectangle {
        id: menuBox
        visible: win.menu !== null
        width: 130; height: 36; radius: 18
        x: win.menu ? Math.max(4, Math.min(win.width - width - 4, win.menu.x - width / 2)) : 0
        y: win.dock.look.edge === "bottom" ? bar.y - height - 8 : bar.y + bar.height + 8
        color: Theme.surface; border.width: 1; border.color: Theme.divider
        Text { anchors.centerIn: parent; text: win.menu && win.menu.pinned ? "Unpin" : "Pin to dock"
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 15; renderType: Text.NativeRendering }
        MouseArea {
            anchors.fill: parent
            onClicked: { if (win.menu.pinned) win.dock.unpin(win.menu.id); else win.dock.pin(win.menu.id); win.menu = null }
        }
    }
}
