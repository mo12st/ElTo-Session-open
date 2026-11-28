// Win7-style This computer: grouped rows, icon left, name, thin glossy bar, "X GB free of Y GB".
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
    component GHead: Item {
        property string label
        width: r.width; height: 26
        Text { id: t; anchors.verticalCenter: parent.verticalCenter; text: parent.label; color: Qt.darker(th.accent, 1.5); font.family: th.sans; font.pixelSize: 15 }
        Rectangle { x: t.width + 10; y: 13; width: parent.width - x - 8; height: 1
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(th.accent, 0.7) }
                GradientStop { position: 1; color: Qt.alpha(th.accent, 0) } } }
    }
    component DRow: Rectangle {
        id: row
        required property var d
        readonly property int pc: page.pct(d)
        width: r.width - 8; height: 54; radius: 4
        color: ma.containsMouse ? Qt.alpha(th.accent, 0.12) : "transparent"
        border.width: ma.containsMouse ? 1 : 0; border.color: Qt.alpha(th.accent, 0.5)
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(row.d.mount) }
        DriveArt { th: r.th; x: 10; y: 8; width: 52; usb: row.d.removable }
        Text { x: 78; y: 4; text: row.d.name; color: th.text; font.family: th.sans; font.pixelSize: 14 }
        Rectangle {
            x: 78; y: 23; width: Math.min(300, row.width - 220); height: 12; radius: 2; color: th.surfaceAlt; border.width: 1; border.color: Qt.alpha(th.text, 0.3)
            Rectangle {
                x: 1; y: 1; width: Math.max(4, (parent.width - 2) * row.pc / 100); height: parent.height - 2; radius: 1
                color: row.pc >= 85 ? th.text : th.accent
                Rectangle { width: parent.width; height: parent.height / 2; color: Qt.alpha("white", 0.4) }
            }
        }
        Text { x: 78; y: 37; text: page.gb(row.d.free) + " free of " + page.gb(row.d.total); color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
        Rectangle {
            visible: row.d.removable && row.d.dev !== ""
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: 60; height: 22; radius: 11; color: th.surface; border.width: 1; border.color: th.divider
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; margins: 2 } height: 9; radius: 5; color: Qt.alpha("white", 0.5) }
            Text { anchors.centerIn: parent; text: "Eject"; color: th.text; font.family: th.sans; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(row.d.dev) }
        }
    }
    Column {
        id: col; width: r.width; spacing: 4
        GHead { label: "Folders (" + page.folders.length + ")" }
        Flow {
            width: r.width
            Repeater {
                model: page.folders
                Rectangle {
                    id: fr
                    required property string modelData
                    readonly property string p: app.home + "/" + modelData
                    width: (r.width - 8) / 3; height: 34; radius: 4
                    color: fma.containsMouse ? Qt.alpha(th.accent, 0.12) : "transparent"
                    border.width: fma.containsMouse ? 1 : 0; border.color: Qt.alpha(th.accent, 0.5)
                    FolderArt { th: r.th; x: 6; anchors.verticalCenter: parent.verticalCenter; width: 30 }
                    Text { x: 44; y: 3; text: fr.modelData; color: th.text; font.family: th.sans; font.pixelSize: 12 }
                    Text { x: 44; y: 18; text: (app.counts[fr.p] || 0) + " items"; color: th.textMuted; font.family: th.sans; font.pixelSize: 9 }
                    MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(fr.p) }
                }
            }
        }
        GHead { visible: r.fixedDrives.length > 0; label: "Hard Disk Drives (" + r.fixedDrives.length + ")" }
        Repeater { model: r.fixedDrives; DRow { required property var modelData; d: modelData } }
        GHead { visible: r.usbDrives.length > 0; label: "Devices with Removable Storage (" + r.usbDrives.length + ")" }
        Repeater { model: r.usbDrives; DRow { required property var modelData; d: modelData } }
    }
}
