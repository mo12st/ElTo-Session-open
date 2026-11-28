// Mono-style This computer: no boxes. Big free-space numerals in hairline columns, folders as one text line.
import QtQuick

Item {
    id: r
    required property var page
    readonly property var th: page.th
    readonly property var app: page.app
    Column {
        width: parent.width; spacing: 26
        Row {
            Repeater {
                model: app.drives
                Item {
                    id: dc
                    required property var modelData
                    required property int index
                    readonly property int pc: page.pct(modelData)
                    width: r.width / Math.max(1, app.drives.length); height: 150
                    Rectangle { visible: dc.index > 0; width: 1; height: parent.height; color: th.divider }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(dc.modelData.mount) }
                    Text { x: 18; y: 0; text: dc.modelData.name; color: th.text; font.family: th.sans; font.pixelSize: 14; font.weight: Font.Medium }
                    Text { x: 18; y: 18; text: dc.modelData.kind; color: th.textMuted; font.family: th.sans; font.pixelSize: 9 }
                    Text { x: 18; y: 34; text: Math.round(dc.modelData.free / 1e9); color: dc.pc >= 85 ? th.accent : th.text; font.family: th.sans; font.weight: Font.Light; font.pixelSize: 64 }
                    Text { x: 18; y: 104; text: "GB free of " + page.gb(dc.modelData.total); color: th.textMuted; font.family: th.sans; font.pixelSize: 11 }
                    Rectangle { x: 18; y: 126; width: parent.width - 36; height: 2; color: th.divider
                        Rectangle { width: parent.width * dc.pc / 100; height: 2; color: dc.pc >= 85 ? th.accent : th.text } }
                    Text {
                        visible: dc.modelData.removable && dc.modelData.dev !== ""
                        anchors { right: parent.right; rightMargin: 18; top: parent.top }
                        text: "Eject"; color: th.text; font.family: th.sans; font.pixelSize: 11; font.underline: true
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(dc.modelData.dev) }
                    }
                }
            }
        }
        Flow {
            width: parent.width; spacing: 28
            Repeater {
                model: page.folders
                Row {
                    id: fl
                    required property string modelData
                    readonly property string p: app.home + "/" + modelData
                    spacing: 6
                    Text { text: fl.modelData; color: th.text; font.family: th.sans; font.pixelSize: 20; font.weight: Font.Light; font.underline: fma.containsMouse
                        MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(fl.p) } }
                    Text { anchors.baseline: undefined; y: 9; text: app.counts[fl.p] || 0; color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
                }
            }
        }
    }
}
