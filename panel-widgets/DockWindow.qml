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
    anchors { bottom: true }
    implicitWidth: Math.max(bar.width + 40, 220)
    implicitHeight: dk.height + dk.bottomMargin + 24 + 64
    color: "transparent"
    mask: Region { item: bar; regions: [ Region { item: menuBox } ] }
    visible: win.dock.style === win.style

    readonly property real barAlpha: dk.glass ? dk.opacity : 1

    Repeater {
        model: 5
        Rectangle {
            required property int index
            x: bar.x - index * 2; y: bar.y + Theme.shadowOffsetY / 3 - index
            width: bar.width + index * 4; height: bar.height + index * 4
            radius: bar.radius + index * 2
            color: Qt.rgba(0, 0, 0, Theme.shadowAlpha / 18 * (win.dk.glass ? 0.6 : 1))
        }
    }

    // click anywhere else closes the menu
    MouseArea { anchors.fill: parent; enabled: win.menu !== null; onClicked: win.menu = null }

    Rectangle {
        id: bar
        height: win.dk.height
        width: row.width + win.dk.pad * 2
        x: (parent.width - width) / 2
        y: parent.height - win.dk.bottomMargin - height
        radius: win.dk.radius
        color: Qt.alpha(Theme.role(win.dk.color), win.barAlpha)
        border.width: win.dk.glass ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.45)
        Behavior on width { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.ms(200) } }

        Row {
            id: row
            x: win.dk.pad
            y: (parent.height - height) / 2
            spacing: win.dk.gap

            Repeater {
                model: win.dock.pinnedItems
                Item {
                    id: app
                    required property var modelData
                    readonly property bool running: win.dock.openApps[modelData.id] === true || win.dock.openApps[modelData.entry.startupClass] === true
                    width: win.dk.tile; height: win.dk.tile
                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        color: Theme.selection
                        opacity: app.running ? 1 : (am.containsMouse ? 0.6 : 0)
                        Behavior on opacity { NumberAnimation { duration: Theme.ms(140) } }
                    }
                    LIcon { visible: app.modelData.glyph !== ""; anchors.centerIn: parent; name: app.modelData.glyph; size: win.dk.icon; tint: Theme.text
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
                    width: win.dk.pillWidth; height: win.dk.pillHeight; radius: height / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: isActive ? Theme.selection : (pm.containsMouse ? Theme.surfaceAlt : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(180) } }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        LIcon { name: "panel-top"; size: 16; tint: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, win.dk.pillWidth - 46); elide: Text.ElideRight
                            text: wp.title !== "" ? wp.title : wp.appid
                            color: Theme.text; font.family: Theme.serif; font.italic: true; font.pixelSize: 14
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

    // right-click menu: one entry, Pin to dock or Unpin
    Rectangle {
        id: menuBox
        visible: win.menu !== null
        width: 130; height: 36; radius: 18
        x: win.menu ? Math.max(4, Math.min(win.width - width - 4, win.menu.x - width / 2)) : 0
        y: bar.y - height - 8
        color: Theme.surface; border.width: 1; border.color: Theme.divider
        Text { anchors.centerIn: parent; text: win.menu && win.menu.pinned ? "Unpin" : "Pin to dock"
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 15; renderType: Text.NativeRendering }
        MouseArea {
            anchors.fill: parent
            onClicked: { if (win.menu.pinned) win.dock.unpin(win.menu.id); else win.dock.pin(win.menu.id); win.menu = null }
        }
    }
}
