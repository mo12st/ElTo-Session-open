// Luna-style This computer: grouped rounded panels with accent headers, drive tiles with capsule bars.
import QtQuick

Flickable {
    id: r
    required property var page
    readonly property var th: page.th
    readonly property var app: page.app
    contentWidth: width; contentHeight: col.height + 10; clip: true; boundsBehavior: Flickable.StopAtBounds
    function group(rem) { var o = []; for (var i = 0; i < app.drives.length; i++) if (!!app.drives[i].removable === rem) o.push(app.drives[i]); return o }
    readonly property var fixedDrives: group(false)
    readonly property var usbDrives: group(true)
    component Panel: Rectangle {
        id: pn
        property string label
        default property alias content: body.data
        width: r.width - 8; height: 30 + body.childrenRect.height + 14; radius: 12
        color: Qt.alpha(th.surface, th.surfaceAlpha); border.width: 2; border.color: th.accent
        Rectangle {
            width: parent.width; height: 26; radius: 10
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.lighter(th.accent, 1.3) }
                GradientStop { position: 1; color: th.accent } }
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: pn.label; color: page.accentText; font.family: th.sans; font.bold: true; font.pixelSize: 13 }
        }
        Item { id: body; x: 12; y: 36; width: parent.width - 24 }
    }
    component Tile: Item {
        id: tile
        required property var d
        readonly property int pc: page.pct(d)
        width: (r.width - 8 - 24 - 10) / 2; height: 64
        Rectangle { anchors.fill: parent; radius: 10; color: tma.containsMouse ? Qt.alpha(th.accent, 0.15) : "transparent" }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(tile.d.mount) }
        DriveArt { th: r.th; x: 6; y: 10; width: 52; usb: tile.d.removable }
        Text { x: 68; y: 6; width: parent.width - 140; elide: Text.ElideRight; text: tile.d.name; color: th.text; font.family: th.sans; font.bold: true; font.pixelSize: 13 }
        Rectangle {
            x: 68; y: 26; width: parent.width - 76; height: 12; radius: 6; color: th.surfaceAlt; border.width: 1; border.color: Qt.alpha("white", 0.9)
            Rectangle { width: Math.max(12, parent.width * tile.pc / 100); height: parent.height; radius: 6; color: tile.pc >= 85 ? th.text : th.accent
                Rectangle { x: 3; y: 1; width: parent.width - 6; height: 4; radius: 2; color: Qt.alpha("white", 0.5) } }
        }
        Text { x: 68; y: 42; text: page.gb(tile.d.free) + " free of " + page.gb(tile.d.total); color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
        Rectangle {
            visible: tile.d.removable && tile.d.dev !== ""
            anchors { right: parent.right; top: parent.top; topMargin: 2 }
            width: 54; height: 20; radius: 10; color: th.accent; border.width: 2; border.color: Qt.alpha("white", 0.9)
            Text { anchors.centerIn: parent; text: "Eject"; color: page.accentText; font.family: th.sans; font.bold: true; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(tile.d.dev) }
        }
    }
    Column {
        id: col; width: r.width; spacing: 12
        Panel {
            label: "Files on this computer"
            Flow {
                width: parent.width
                Repeater {
                    model: page.folders
                    Item {
                        id: fc
                        required property string modelData
                        readonly property string p: app.home + "/" + modelData
                        width: parent.width / page.folders.length; height: 82
                        FolderArt { th: r.th; width: 52; anchors { top: parent.top; horizontalCenter: parent.horizontalCenter } }
                        Text { anchors { top: parent.top; topMargin: 52; horizontalCenter: parent.horizontalCenter } text: fc.modelData; color: th.text; font.family: th.sans; font.bold: true; font.pixelSize: 11 }
                        Text { anchors { top: parent.top; topMargin: 67; horizontalCenter: parent.horizontalCenter } text: (app.counts[fc.p] || 0) + " items"; color: th.textMuted; font.family: th.sans; font.pixelSize: 9 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(fc.p) }
                    }
                }
            }
        }
        Panel {
            visible: r.fixedDrives.length > 0; label: "Hard disk drives"
            Flow { width: parent.width; spacing: 10; Repeater { model: r.fixedDrives; Tile { required property var modelData; d: modelData } } }
        }
        Panel {
            visible: r.usbDrives.length > 0; label: "Devices with removable storage"
            Flow { width: parent.width; spacing: 10; Repeater { model: r.usbDrives; Tile { required property var modelData; d: modelData } } }
        }
    }
}
