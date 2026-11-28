// Meadow This computer: sky-blue glossy group bands over big desktop-style icons. Drive icons carry a capsule bar.
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
    readonly property color bandTop: th.bandTop
    readonly property color bandBottom: th.bandBottom
    component Band: Rectangle {
        id: bd
        property string label
        width: r.width - 8; height: 26; radius: 8
        gradient: Gradient { GradientStop { position: 0; color: r.bandTop } GradientStop { position: 1; color: r.bandBottom } }
        Rectangle { x: 2; y: 2; width: parent.width - 4; height: parent.height / 2 - 2; radius: 6; color: Qt.alpha("white", 0.28) }
        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: bd.label; color: th.surface; font.family: th.sans; font.bold: true; font.pixelSize: 13 }
    }
    component Icon: Item {
        id: ic
        property var d: null
        property string nm: ""
        readonly property int pc: d ? page.pct(d) : 0
        width: 128; height: d ? 124 : 104
        Rectangle { anchors { fill: parent; margins: 2 } radius: 8; color: ma.containsMouse ? Qt.alpha(th.selection, 0.8) : "transparent"; border.width: ma.containsMouse ? 1 : 0; border.color: th.bandBottom }
        DriveArt { visible: ic.d !== null; th: r.th; width: 64; anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter } usb: ic.d !== null && ic.d.removable }
        FolderArt { visible: ic.d === null; th: r.th; width: 64; anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter } }
        Text { anchors { top: parent.top; topMargin: 66; horizontalCenter: parent.horizontalCenter } width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: ic.d ? ic.d.name : ic.nm; color: th.text; font.family: th.sans; font.pixelSize: 12; font.weight: Font.Medium }
        Rectangle { visible: ic.d !== null; x: 22; y: 86; width: 84; height: 8; radius: 4; color: th.surfaceAlt; border.width: 1; border.color: Qt.alpha(th.text, 0.25)
            Rectangle { width: Math.max(8, parent.width * ic.pc / 100); height: parent.height; radius: 4; color: ic.pc >= 85 ? th.text : th.accent
                Rectangle { x: 2; y: 1; width: parent.width - 4; height: 3; radius: 1.5; color: Qt.alpha("white", 0.55) } } }
        Text { anchors { top: parent.top; topMargin: ic.d ? 98 : 84; horizontalCenter: parent.horizontalCenter }
            text: ic.d ? page.gb(ic.d.free) + " free of " + page.gb(ic.d.total) : (app.counts[app.home + "/" + ic.nm] || 0) + " items"
            color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
        Text {
            visible: ic.d !== null && ic.d.removable && ic.d.dev !== ""
            anchors { right: parent.right; top: parent.top; margins: 6 }
            text: "Eject"; color: th.text; font.family: th.sans; font.pixelSize: 10; font.underline: true
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(ic.d.dev) }
        }
        MouseArea { id: ma; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(ic.d ? ic.d.mount : app.home + "/" + ic.nm) }
    }
    Column {
        id: col; width: r.width; spacing: 8
        Band { label: "Files on this computer" }
        Flow { width: r.width; Repeater { model: page.folders; Icon { required property string modelData; nm: modelData } } }
        Band { visible: r.fixedDrives.length > 0; label: "Hard disk drives" }
        Flow { width: r.width; Repeater { model: r.fixedDrives; Icon { required property var modelData; d: modelData } } }
        Band { visible: r.usbDrives.length > 0; label: "Devices with removable storage" }
        Flow { width: r.width; Repeater { model: r.usbDrives; Icon { required property var modelData; d: modelData } } }
    }
}
