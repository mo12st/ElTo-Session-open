// Chrome-style This computer: ring gauges per drive, then an angular folder tab strip.
import QtQuick

Item {
    id: r
    required property var page
    readonly property var th: page.th
    readonly property var app: page.app
    component Lab: Item {
        property string label
        width: r.width; height: 22
        Text { id: t; text: parent.label.toUpperCase(); color: th.accent; font.family: th.sans; font.bold: true; font.letterSpacing: 3; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        Rectangle { x: t.width + 10; y: 11; width: parent.width - x; height: 1; color: Qt.alpha(th.accent, 0.5) }
    }
    Column {
        width: parent.width; spacing: 10
        Lab { label: "Drives" }
        Row {
            spacing: 12
            Repeater {
                model: app.drives
                Rectangle {
                    id: gcd
                    required property var modelData
                    readonly property int pc: page.pct(modelData)
                    width: (r.width - 24) / 3; height: 118; radius: 3
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(th.surface, 1.5) }
                        GradientStop { position: 1; color: Qt.darker(th.surface, 1.5) } }
                    border.width: 1; border.color: Qt.alpha(th.accent, 0.7)
                    Canvas {
                        id: ring; x: 10; y: 14; width: 84; height: 84
                        onPaint: {
                            var c = getContext("2d"); c.reset(); c.lineWidth = 9; c.lineCap = "butt"
                            c.strokeStyle = Qt.alpha(th.text, 0.18).toString(); c.beginPath(); c.arc(42, 42, 36, 0, Math.PI * 2); c.stroke()
                            c.strokeStyle = th.accent.toString(); c.beginPath()
                            c.arc(42, 42, 36, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * gcd.pc / 100); c.stroke()
                        }
                        Component.onCompleted: requestPaint()
                        Connections { target: gcd; function onPcChanged() { ring.requestPaint() } }
                    }
                    Text { x: 10; y: 14; width: 84; height: 84; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: gcd.pc + "%"; color: gcd.pc >= 85 ? th.accent : th.text; font.family: th.sans; font.bold: true; font.pixelSize: 20 }
                    Text { x: 106; y: 14; width: parent.width - 116; elide: Text.ElideRight; text: gcd.modelData.name.toUpperCase(); color: th.text; font.family: th.sans; font.bold: true; font.letterSpacing: 1.5; font.pixelSize: 14 }
                    Text { x: 106; y: 36; width: parent.width - 116; elide: Text.ElideRight; text: gcd.modelData.kind; color: th.textMuted; font.family: th.sans; font.pixelSize: 9 }
                    Text { x: 106; y: 56; text: page.gb(gcd.modelData.free) + " FREE"; color: th.accent; font.family: th.sans; font.bold: true; font.pixelSize: 12 }
                    Text { x: 106; y: 72; text: "OF " + page.gb(gcd.modelData.total); color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
                    Rectangle {
                        visible: gcd.modelData.removable && gcd.modelData.dev !== ""
                        x: 106; y: 90; width: 60; height: 20; color: "transparent"; border.width: 1; border.color: th.accent
                        Text { anchors.centerIn: parent; text: "EJECT"; color: th.accent; font.family: th.sans; font.letterSpacing: 1; font.pixelSize: 9 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(gcd.modelData.dev) }
                    }
                    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(gcd.modelData.mount) }
                }
            }
        }
        Item { width: 1; height: 8 }
        Lab { label: "Folders" }
        Row {
            spacing: 6
            Repeater {
                model: page.folders
                Rectangle {
                    id: ft
                    required property string modelData
                    readonly property string p: app.home + "/" + modelData
                    width: (r.width - 24) / 5; height: 44; color: fma.containsMouse ? Qt.alpha(th.accent, 0.2) : Qt.alpha(th.surface, 0.7)
                    border.width: 1; border.color: Qt.alpha(th.accent, 0.4)
                    Rectangle { width: parent.width; height: 3; y: parent.height - 3; color: th.accent }
                    FolderArt { th: r.th; x: 6; y: 8; width: 32 }
                    Text { x: 44; y: 7; text: ft.modelData.toUpperCase(); color: th.text; font.family: th.sans; font.bold: true; font.letterSpacing: 1; font.pixelSize: 10 }
                    Text { x: 44; y: 22; text: (app.counts[ft.p] || 0) + " ITEMS"; color: th.textMuted; font.family: th.sans; font.pixelSize: 9 }
                    MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(ft.p) }
                }
            }
        }
    }
}
