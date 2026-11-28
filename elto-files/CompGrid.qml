// Win95-style This computer: plain icon grid, no cards, status bar at the bottom.
import QtQuick

Item {
    id: g
    required property var page
    readonly property var th: page.th
    readonly property var app: page.app
    readonly property var items: {
        var r = []
        for (var i = 0; i < app.drives.length; i++) r.push({ drive: true, d: app.drives[i], name: app.drives[i].name })
        for (var j = 0; j < page.folders.length; j++) r.push({ drive: false, name: page.folders[j] })
        return r
    }
    Flow {
        width: parent.width; spacing: 6
        Repeater {
            model: g.items
            Item {
                id: cell
                required property var modelData
                readonly property bool hov: ma.containsMouse
                width: 104; height: 104
                Item {
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter } width: 56; height: 46
                    DriveArt { visible: cell.modelData.drive; th: g.th; width: 52; anchors.centerIn: parent; usb: cell.modelData.drive && cell.modelData.d.removable }
                    FolderArt { visible: !cell.modelData.drive; th: g.th; width: 52; anchors.centerIn: parent }
                }
                Rectangle {
                    anchors { top: parent.top; topMargin: 52; horizontalCenter: parent.horizontalCenter }
                    width: lab.width + 6; height: lab.height + 2; color: cell.hov ? th.selection : "transparent"
                    border.width: cell.hov ? 1 : 0; border.color: th.text
                    Text { id: lab; anchors.centerIn: parent; text: cell.modelData.name; color: cell.hov ? th.onSel() : th.text; font.family: th.sans; font.pixelSize: 11 }
                }
                Text {
                    anchors { top: parent.top; topMargin: 72; horizontalCenter: parent.horizontalCenter }
                    text: cell.modelData.drive ? page.pct(cell.modelData.d) + "% used" : (app.counts[app.home + "/" + cell.modelData.name] || 0) + " items"
                    color: th.textMuted; font.family: th.sans; font.pixelSize: 9
                }
                Text {
                    visible: cell.modelData.drive && cell.modelData.d.removable && cell.modelData.d.dev !== ""
                    anchors { top: parent.top; topMargin: 86; horizontalCenter: parent.horizontalCenter }
                    text: "Eject"; color: th.text; font.family: th.sans; font.pixelSize: 9; font.underline: true
                    MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(cell.modelData.d.dev) }
                }
                MouseArea {
                    id: ma; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: app.openPath(cell.modelData.drive ? cell.modelData.d.mount : app.home + "/" + cell.modelData.name)
                }
            }
        }
    }
    Rectangle {   // status bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
        height: 22; color: "transparent"
        Bevel { th: g.th; raised: false }
        Text {
            x: 8; anchors.verticalCenter: parent.verticalCenter; color: th.text; font.family: th.sans; font.pixelSize: 11
            text: g.items.length + " object(s)   |   " + app.drives.length + " drive(s), " + page.folders.length + " folder(s)"
        }
    }
}
