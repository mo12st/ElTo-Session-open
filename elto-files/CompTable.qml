// Terminal-style This computer: a df -h style table and an ls -l style folder listing, all monospace text.
import QtQuick

Flickable {
    id: r
    required property var page
    readonly property var th: page.th
    readonly property var app: page.app
    contentWidth: width; contentHeight: col.height + 10; clip: true; boundsBehavior: Flickable.StopAtBounds
    function pad(s, n) { s = String(s); return s.length >= n ? s.substring(0, n) : s + " ".repeat(n - s.length) }
    function lpad(s, n) { s = String(s); return s.length >= n ? s : " ".repeat(n - s.length) + s }
    function bar(pc) { var n = Math.round(pc / 10); return "[" + "#".repeat(n) + "-".repeat(10 - n) + "]" }
    component Line: Text { color: th.text; font.family: th.mono; font.pixelSize: 12 }
    Column {
        id: col; width: r.width; spacing: 3
        Line { text: "$ df -h"; color: th.accent }
        Line { text: r.pad("Filesystem", 14) + r.lpad("Size", 8) + r.lpad("Used", 8) + r.lpad("Avail", 8) + "  " + r.pad("Capacity", 13) + "Mounted on"; color: th.textMuted }
        Repeater {
            model: app.drives
            Item {
                id: tr
                required property var modelData
                readonly property int pc: page.pct(modelData)
                width: r.width; height: 18
                Rectangle { anchors.fill: parent; color: ma.containsMouse ? Qt.alpha(th.accent, 0.15) : "transparent" }
                Line {
                    text: r.pad(tr.modelData.name, 14) + r.lpad(page.gb(tr.modelData.total), 8) + r.lpad(page.gb(tr.modelData.used), 8) + r.lpad(page.gb(tr.modelData.free), 8) + "  " + r.bar(tr.pc) + r.lpad(tr.pc + "%", 4) + "  " + tr.modelData.mount
                    color: tr.pc >= 85 ? th.accent : th.text
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(tr.modelData.mount) }
                Text {
                    visible: tr.modelData.removable && tr.modelData.dev !== ""
                    anchors { right: parent.right; rightMargin: 4 }
                    text: "[eject]"; color: th.accent; font.family: th.mono; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(tr.modelData.dev) }
                }
            }
        }
        Item { width: 1; height: 12 }
        Line { text: "$ ls -l ~"; color: th.accent }
        Line { text: "total " + page.folders.length; color: th.textMuted }
        Repeater {
            model: page.folders
            Item {
                id: lr
                required property string modelData
                readonly property string p: app.home + "/" + modelData
                width: r.width; height: 18
                Rectangle { anchors.fill: parent; color: fma.containsMouse ? Qt.alpha(th.accent, 0.15) : "transparent" }
                Line { text: "drwxr-xr-x  " + r.lpad(app.counts[lr.p] || 0, 5) + "  " + lr.modelData + "/" }
                MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(lr.p) }
            }
        }
        Line { text: "$ _"; color: th.accent }
    }
}
