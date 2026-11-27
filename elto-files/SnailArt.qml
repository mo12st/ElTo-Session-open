// Small snail drawn from theme colours.
import QtQuick

Canvas {
    id: c
    required property var th
    implicitWidth: 28; implicitHeight: 21
    width: implicitWidth; height: implicitHeight
    readonly property string key: th.text.toString() + th.textMuted.toString() + th.selection.toString()
    onKeyChanged: requestPaint()
    onPaint: {
        var g = getContext("2d"); g.reset(); g.scale(width / 32, height / 24)
        g.lineCap = "round"; g.lineWidth = 3; g.strokeStyle = th.textMuted.toString()
        g.beginPath(); g.moveTo(3, 21); g.lineTo(25, 21); g.quadraticCurveTo(29, 21, 29, 17); g.lineTo(29, 14); g.stroke()
        g.lineWidth = 1.5
        g.beginPath(); g.moveTo(27, 14); g.lineTo(28, 7); g.moveTo(30, 14); g.lineTo(32, 8); g.stroke()
        g.fillStyle = th.text.toString(); g.beginPath(); g.arc(13, 12, 8, 0, Math.PI * 2); g.fill()
        g.strokeStyle = th.selection.toString(); g.lineWidth = 1.4
        g.beginPath(); g.arc(13, 12, 5, 0.3, Math.PI * 1.7); g.arc(13, 12, 2.4, Math.PI * 1.7, Math.PI * 0.4, true); g.stroke()
    }
}
