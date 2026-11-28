// The dock "Island" variant: a floating island bar with pinned apps, divider, one pill per open window,
// and a small right-click menu (Pin / Unpin).
// All look values come from Theme (dock section): color role, glass opacity, shape.
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
    readonly property string style: "island"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "elto-dock"
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: win.dock.look.edge === "bottom"; top: win.dock.look.edge === "top" }
    implicitWidth: Math.max(bar.width + 40, 220)
    implicitHeight: win.dock.look.height + win.dk.bottomMargin + 24 + 64
    color: "transparent"
    mask: Region { item: bar; regions: [ Region { item: menuBox } ] }
    visible: win.dock.style === win.style

    readonly property real barAlpha: (dk.glass || win.dock.look.material === "glass") ? dk.opacity : 1

    Repeater {
        model: 5
        Rectangle {
            required property int index
            x: bar.x - index * 2
            y: win.dock.look.edge === "bottom" ? bar.y + Theme.shadowOffsetY / 3 - index : bar.y + Theme.shadowOffsetY / 3 + index
            width: bar.width + index * 4; height: bar.height + index * 4
            radius: bar.radius + index * 2
            color: Qt.rgba(0, 0, 0, Theme.shadowAlpha / 18 * (win.dk.glass ? 0.6 : 1))
        }
    }

    // click anywhere else closes the menu
    MouseArea { anchors.fill: parent; enabled: win.menu !== null; onClicked: win.menu = null }

    Rectangle {
        id: bar
        readonly property string mat: win.dock.look.material
        height: win.dock.look.height
        width: row.width + win.dk.pad * 2
        x: (parent.width - width) / 2
        y: win.dock.look.edge === "bottom" ? parent.height - win.dk.bottomMargin - height : win.dk.bottomMargin
        radius: win.dock.look.radius
        color: Qt.alpha(Theme.role(win.dk.color), win.barAlpha)
        border.width: bar.mat === "glass" ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.45)

        // 95-style bevel: light on the top and left, dark on the bottom and right
        Rectangle { visible: bar.mat === "bevel"; anchors { left: parent.left; right: parent.right; top: parent.top } height: 2; color: Qt.rgba(1, 1, 1, 0.7) }
        Rectangle { visible: bar.mat === "bevel"; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 2; color: Qt.rgba(1, 1, 1, 0.7) }
        Rectangle { visible: bar.mat === "bevel"; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 2; color: Qt.rgba(0, 0, 0, 0.35) }
        Rectangle { visible: bar.mat === "bevel"; anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 2; color: Qt.rgba(0, 0, 0, 0.35) }

        // material: gloss adds a highlight band, the default paper keeps the flat fill above
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            visible: bar.mat === "gloss"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.43; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }
        Behavior on width { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.ms(200) } }

        Row {
            id: row
            x: win.dk.pad
            y: (parent.height - height) / 2
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
            // clock at the leading edge, when the world asks for it
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

            Rectangle { visible: win.dock.wl !== null && win.dock.wl.model.count > 0; width: 1; height: win.dk.tile * 0.7; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }

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

            Rectangle { width: 1; height: win.dk.tile * 0.7; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }

            DockSystemArea { textSize: 13; trayStyle: win.dock.look.trayStyle; clockStyle: win.dock.look.clockStyle; clockPosition: win.dock.look.clockPosition; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // right-click menu: one entry, Pin to dock or Unpin
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
