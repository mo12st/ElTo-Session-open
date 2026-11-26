// ElTo app drawer (CONCEPT until approved): a small paper sheet centered on the screen. Opened from the snail in the notch.
// Real installed apps (desktop entries) with their real icons from the icon theme. Look values come from Theme (drawer section).
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick

PanelWindow {
    id: win
    property bool open: false
    property string query: ""
    readonly property var dr: Theme.drawerT

    function toggle() {
        open = !open
        if (open) { query = ""; search.text = ""; grid.currentIndex = 0; search.forceActiveFocus() }
    }
    function launch(e) { e.execute(); open = false }

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: true
    // always mapped; empty mask while closed so clicks pass through
    mask: Region { width: sheet.visible ? win.width : 0; height: sheet.visible ? win.height : 0 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "elto-drawer"
    WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    IpcHandler { target: "drawer"; function toggle(): void { win.toggle() } }

    ScriptModel {
        id: filtered
        values: {
            const q = win.query.trim().toLowerCase()
            const all = [...DesktopEntries.applications.values].filter(e => !e.noDisplay)
            const hits = q === "" ? all : all.filter(e => e.name.toLowerCase().includes(q))
            return hits.sort((a, b) => a.name.localeCompare(b.name))
        }
    }

    // click outside the sheet closes it
    MouseArea { anchors.fill: parent; enabled: win.open; onClicked: win.open = false }

    Item {
        id: sheet
        visible: opacity > 0.01
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.ms(win.dr.openMs); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.ms(win.dr.openMs); easing.type: Easing.OutCubic } }
        width: win.dr.width; height: win.dr.height
        x: (win.width - width) / 2
        y: (win.height - height) / 2 - 20

        // soft shadow
        Repeater {
            model: 6
            Rectangle {
                required property int index
                x: front.x - index * 3; y: front.y + 10 - index * 1.5
                width: front.width + index * 6; height: front.height + index * 6
                radius: win.dr.radius + index * 3
                color: Qt.rgba(0, 0, 0, Theme.shadowAlpha / 16)
                rotation: win.dr.tilt
            }
        }
        // second sheet peeking out behind
        Rectangle {
            x: 8; y: 10; width: parent.width; height: parent.height; radius: win.dr.radius
            rotation: win.dr.backTilt; clip: true; color: Theme.surfaceAlt
            Image { anchors.fill: parent; source: "file://" + Quickshell.shellPath("../textures/paper.png"); fillMode: Image.Tile; opacity: 0.9 }
            border.width: 1; border.color: Theme.divider
        }
        // front sheet
        Rectangle {
            id: front
            anchors.fill: parent; radius: win.dr.radius; clip: true; color: Theme.surface
            rotation: win.dr.tilt
            border.width: 1; border.color: Theme.divider
            Image { anchors.fill: parent; source: "file://" + Quickshell.shellPath("../textures/paper.png"); fillMode: Image.Tile }

            MouseArea { anchors.fill: parent }   // clicks on the sheet do not reach the close area

            Text {
                x: win.dr.pad; y: 12; text: "Apps"
                color: Theme.text; font.family: Theme.serif; font.pixelSize: 28; renderType: Text.NativeRendering
            }
            Rectangle { x: win.dr.pad; y: 52; width: parent.width - win.dr.pad * 2; height: 1; color: Theme.divider }

            Rectangle {
                id: box
                x: win.dr.pad; y: 62; width: parent.width - win.dr.pad * 2; height: 32; radius: 16
                color: Theme.surfaceAlt
                LIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; tint: Theme.textMuted }
                TextInput {
                    id: search
                    anchors.fill: parent; anchors.leftMargin: 40; anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.sans; font.pixelSize: 15; color: Theme.text
                    onTextChanged: { win.query = text; grid.currentIndex = 0 }
                    Keys.onEscapePressed: win.open = false
                    Keys.onReturnPressed: { if (filtered.values.length > 0) win.launch(filtered.values[Math.max(0, grid.currentIndex)]) }
                    Keys.onDownPressed: grid.moveCurrentIndexDown()
                    Keys.onUpPressed: grid.moveCurrentIndexUp()
                    Keys.onLeftPressed: e => { if (text === "") grid.moveCurrentIndexLeft(); else e.accepted = false }
                    Keys.onRightPressed: e => { if (text === "") grid.moveCurrentIndexRight(); else e.accepted = false }
                }
                Text { anchors.fill: search; verticalAlignment: Text.AlignVCenter; text: "Search apps"; visible: search.text === ""
                    font.family: Theme.sans; font.pixelSize: 15; color: Theme.disabled }
            }

            GridView {
                id: grid
                x: win.dr.pad; y: 104; width: parent.width - win.dr.pad * 2; height: parent.height - 104 - 36
                clip: true; model: filtered; currentIndex: 0
                cellWidth: width / win.dr.cols; cellHeight: win.dr.cell
                highlightMoveDuration: Theme.ms(120)
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth; height: grid.cellHeight
                    readonly property bool cur: GridView.isCurrentItem
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 3; radius: Theme.radiusCard
                        color: cell.cur || ma.containsMouse ? Theme.selection : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
                    }
                    Rectangle {
                        id: tile
                        width: win.dr.tile; height: width; radius: Theme.radiusCard
                        anchors.horizontalCenter: parent.horizontalCenter; y: 6
                        color: Theme.surface; border.width: 1; border.color: Theme.divider
                        IconImage {
                            anchors.centerIn: parent; implicitSize: win.dr.icon
                            source: cell.modelData.icon !== "" && Quickshell.iconPath(cell.modelData.icon, true) !== ""
                                    ? Quickshell.iconPath(cell.modelData.icon, true)
                                    : Quickshell.iconPath("application-x-executable")
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 6 + win.dr.tile + 4
                        width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: cell.modelData.name; color: Theme.text; font.family: Theme.sans; font.pixelSize: 12
                    }
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true
                        onEntered: grid.currentIndex = cell.index
                        onClicked: win.launch(cell.modelData)
                    }
                }
            }
            Rectangle { x: win.dr.pad; y: parent.height - 32; width: parent.width - win.dr.pad * 2; height: 1; color: Theme.divider }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 24; text: "Enter to open  \u00b7  Esc to close"
                color: Theme.textMuted; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 12; renderType: Text.NativeRendering }
        }
    }
}
