// Meadow This computer, in the spirit of an early-2000s explorer: collapsible gradient group headers,
// bright folder icons, and drive tiles with a segmented green bar. Original art, token colours only.
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
    // A group: gradient header with a collapse button, and the content below it.
    component Group: Column {
        id: grp
        property string label
        property bool open: true
        default property alias content: holder.data
        width: r.width - 8
        Rectangle {
            width: parent.width; height: 26; radius: 6
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.lighter(th.selection, 1.35) }
                GradientStop { position: 1; color: Qt.darker(th.selection, 1.1) } }
            border.width: 1; border.color: th.bandTop
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: grp.label; color: th.bandBottom; font.family: th.sans; font.bold: true; font.pixelSize: 13 }
            Rectangle {
                width: 18; height: 18; radius: 9; x: parent.width - 26; anchors.verticalCenter: parent.verticalCenter
                color: Qt.lighter(th.selection, 1.3); border.width: 1; border.color: th.bandTop
                LIcon { th: r.th; anchors.centerIn: parent; size: 10; name: "chev-left"; tint: th.bandBottom; rotation: grp.open ? 90 : -90 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: grp.open = !grp.open }
        }
        Item { id: holder; visible: grp.open; width: parent.width; height: grp.open ? childrenRect.height + 10 : 0 }
    }
    component FolderCell: Item {
        id: fc
        property string nm
        width: 112; height: 100
        Rectangle { anchors { fill: parent; margins: 2 } radius: 4; color: ma.containsMouse ? Qt.alpha(th.selection, 0.8) : "transparent"; border.width: ma.containsMouse ? 1 : 0; border.color: th.bandTop }
        FolderArt { th: r.th; width: 60; anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter } }
        Text { anchors { top: parent.top; topMargin: 64; horizontalCenter: parent.horizontalCenter } text: fc.nm; color: th.text; font.family: th.sans; font.pixelSize: 12; font.underline: ma.containsMouse }
        Text { anchors { top: parent.top; topMargin: 80; horizontalCenter: parent.horizontalCenter } text: (app.counts[app.home + "/" + fc.nm] || 0) + " items"; color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(app.home + "/" + fc.nm) }
    }
    component DriveTile: Item {
        id: dt
        property var d
        readonly property int pc: d ? page.pct(d) : 0
        width: Math.floor((r.width - 8) / 2); height: 88
        Rectangle {   // tile frame, drawn on hover
            anchors { fill: parent; margins: 2 } radius: 5
            visible: ma.containsMouse
            gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(th.selection, 1.25) } GradientStop { position: 1; color: th.selection } }
            border.width: 1; border.color: th.bandTop
        }
        DriveArt { th: r.th; x: 12; y: 14; width: 68; usb: dt.d && dt.d.removable }
        Text { x: 94; y: 10; width: parent.width - 170; elide: Text.ElideRight; text: dt.d ? dt.d.name : ""; color: th.text; font.family: th.sans; font.bold: true; font.pixelSize: 13 }
        Rectangle {   // bordered capacity bar
            id: track
            x: 94; y: 32; width: parent.width - 116; height: 15; color: th.surface; border.width: 1; border.color: th.bandBottom
            Canvas {
                x: 2; y: 2; width: Math.max(0, (parent.width - 4) * dt.pc / 100); height: parent.height - 4
                onWidthChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"); c.reset(); c.fillStyle = (dt.pc >= 85 ? th.bandBottom : th.accent).toString()
                    for (var x = 0; x + 7 <= width; x += 9) c.fillRect(x, 0, 7, height)
                }
            }
        }
        Text { x: 94; y: 52; text: dt.d ? page.gb(dt.d.free) + " free of " + page.gb(dt.d.total) : ""; color: th.text; font.family: th.sans; font.pixelSize: 11 }
        Text { x: 94; y: 68; width: parent.width - 116; elide: Text.ElideRight; text: dt.d ? dt.d.kind : ""; color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
        Text {
            visible: dt.d && dt.d.removable && dt.d.dev !== ""
            anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 10 }
            text: "Eject"; color: th.bandBottom; font.family: th.sans; font.pixelSize: 11; font.underline: true
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(dt.d.dev) }
        }
        MouseArea { id: ma; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(dt.d.mount) }
    }
    Column {
        id: col; width: r.width; spacing: 10
        Group {
            label: "Files stored on this computer"
            Flow { width: parent.width; Repeater { model: page.folders; FolderCell { required property string modelData; nm: modelData } } }
        }
        Group {
            visible: r.fixedDrives.length > 0; label: "Hard disk drives"
            Flow { width: parent.width; Repeater { model: r.fixedDrives; DriveTile { required property var modelData; d: modelData } } }
        }
        Group {
            visible: r.usbDrives.length > 0; label: "Devices with removable storage"
            Flow { width: parent.width; Repeater { model: r.usbDrives; DriveTile { required property var modelData; d: modelData } } }
        }
    }
}
