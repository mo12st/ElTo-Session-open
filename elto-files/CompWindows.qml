// Retro 95 This computer: a stack of framed windows. One for folders, one per drive, each with a title bar.
import QtQuick

Flickable {
    id: r
    required property var page
    readonly property var th: page.th
    readonly property var app: page.app
    contentWidth: width; contentHeight: col.height + 14; clip: true; boundsBehavior: Flickable.StopAtBounds
    readonly property color barText: th.lum(th.accent) < 0.5 ? th.surface : th.text
    component Win: Rectangle {
        id: w
        property string label
        default property alias content: body.data
        property real bodyH: 60
        width: r.width - 10; height: 20 + bodyH; color: th.surface; border.width: 2; border.color: th.text
        Rectangle { x: 5; y: 5; z: -1; width: parent.width; height: parent.height; color: Qt.alpha(th.text, 0.4) }
        Bevel { th: r.th }
        Rectangle {
            x: 2; y: 2; width: parent.width - 4; height: 18
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: th.accent }
                GradientStop { position: 1; color: th.selection } }
            Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: w.label; color: r.barText; font.family: th.mono; font.bold: true; font.pixelSize: 12 }
            Row { anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } spacing: 3
                Repeater { model: 3; Rectangle { width: 10; height: 10; color: th.surface; border.width: 1; border.color: th.text } } }
        }
        Item { id: body; x: 2; y: 22; width: parent.width - 4; height: parent.height - 24 }
    }
    Column {
        id: col; width: r.width; spacing: 12
        Win {
            label: "Folders"; bodyH: 84
            Row {
                x: 6; y: 6; width: parent.width - 12
                Repeater {
                    model: page.folders
                    Item {
                        id: fc
                        required property string modelData
                        readonly property string p: app.home + "/" + modelData
                        width: parent.width / page.folders.length; height: 72
                        FolderArt { th: r.th; width: 48; anchors { top: parent.top; horizontalCenter: parent.horizontalCenter } }
                        Text { anchors { top: parent.top; topMargin: 46; horizontalCenter: parent.horizontalCenter } text: fc.modelData; color: th.text; font.family: th.mono; font.pixelSize: 12 }
                        Text { anchors { top: parent.top; topMargin: 60; horizontalCenter: parent.horizontalCenter } text: (app.counts[fc.p] || 0) + " items"; color: th.textMuted; font.family: th.mono; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(fc.p) }
                    }
                }
            }
        }
        Repeater {
            model: app.drives
            Win {
                id: dw
                required property var modelData
                readonly property int pc: page.pct(modelData)
                label: modelData.name + (modelData.removable ? "  [removable]" : "")
                bodyH: 62
                DriveArt { th: r.th; x: 10; y: 8; width: 52; usb: dw.modelData.removable }
                Text { x: 76; y: 6; text: page.gb(dw.modelData.free) + " free of " + page.gb(dw.modelData.total); color: th.text; font.family: th.mono; font.pixelSize: 12 }
                Rectangle {
                    id: tr
                    x: 76; y: 28; width: parent.width - 76 - 100; height: 14; color: Qt.lighter(th.surface, 1.25); border.width: 2; border.color: th.text
                    Rectangle { x: 2; y: 2; width: Math.max(8, (parent.width - 4) * dw.pc / 100); height: parent.height - 4; color: dw.pc >= 85 ? th.accent : th.textMuted; clip: true
                        Canvas { anchors.fill: parent
                            onPaint: { var c = getContext("2d"); c.reset(); c.fillStyle = Qt.alpha(th.surface, 0.5).toString(); for (var x = 0; x < width; x += 8) c.fillRect(x, 0, 4, height) } } }
                }
                Text { x: tr.x + tr.width + 8; y: 28; text: dw.pc + "%"; color: dw.pc >= 85 ? th.accent : th.text; font.family: th.mono; font.bold: true; font.pixelSize: 13 }
                Rectangle {
                    visible: dw.modelData.removable && dw.modelData.dev !== ""
                    x: parent.width - 80; y: 6; width: 64; height: 20; color: th.accent; border.width: 2; border.color: th.text
                    Text { anchors.centerIn: parent; text: "Eject"; color: r.barText; font.family: th.mono; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(dw.modelData.dev) }
                }
                MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(dw.modelData.mount) }
            }
        }
    }
}
