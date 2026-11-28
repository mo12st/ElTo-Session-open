// Small snail. Style from the token shape.snail: solid (default), outline, pixel, glass. Style only, no behaviour.
import QtQuick

Canvas {
    id: c
    required property var th
    implicitWidth: 28; implicitHeight: 21
    width: implicitWidth; height: implicitHeight
    readonly property string style: th.snailStyle
    readonly property string key: style + th.text.toString() + th.textMuted.toString() + th.selection.toString() + th.surface.toString()
    onKeyChanged: requestPaint()
    readonly property var pix: [
        "..........1.1...",
        "...........1.1..",
        "....22222...11..",
        "...2222222..11..",
        "..222.33.22.11..",
        "..22.3223.2.11..",
        "..22.3.33.2.11..",
        "..222.333.221...",
        ".1.2222222.111..",
        "1111122222111111"]
    onPaint: {
        var g = getContext("2d"); g.reset()
        if (style === "pixel") {
            var cw = width / 16, ch = height / 10
            for (var y = 0; y < pix.length; y++) for (var x = 0; x < 16; x++) {
                var k = pix[y][x]; if (k === ".") continue
                g.fillStyle = (k === "1" ? th.textMuted : (k === "2" ? th.text : th.selection)).toString()
                g.fillRect(Math.floor(x * cw), Math.floor(y * ch), Math.ceil(cw), Math.ceil(ch))
            }
            return
        }
        g.scale(width / 32, height / 24)
        g.lineCap = "round"; g.lineJoin = "round"
        g.lineWidth = style === "outline" ? 1.8 : 3; g.strokeStyle = (style === "outline" ? th.text : th.textMuted).toString()
        g.beginPath(); g.moveTo(3, 21); g.lineTo(25, 21); g.quadraticCurveTo(29, 21, 29, 17); g.lineTo(29, 14); g.stroke()
        g.lineWidth = 1.5
        g.beginPath(); g.moveTo(27, 14); g.lineTo(28, 7); g.moveTo(30, 14); g.lineTo(32, 8); g.stroke()
        if (style === "solid") { g.fillStyle = th.text.toString(); g.beginPath(); g.arc(13, 12, 8, 0, Math.PI * 2); g.fill() }
        else if (style === "glass") { g.fillStyle = Qt.alpha(th.surface, 0.5).toString(); g.beginPath(); g.arc(13, 12, 8, 0, Math.PI * 2); g.fill()
            g.strokeStyle = Qt.alpha(th.surface, 0.95).toString(); g.lineWidth = 1.4; g.beginPath(); g.arc(13, 12, 8, 0, Math.PI * 2); g.stroke() }
        else { g.strokeStyle = th.text.toString(); g.lineWidth = 1.8; g.beginPath(); g.arc(13, 12, 8, 0, Math.PI * 2); g.stroke() }
        g.strokeStyle = (style === "solid" ? th.selection : (style === "glass" ? Qt.alpha(th.text, 0.7) : th.text)).toString(); g.lineWidth = 1.4
        g.beginPath(); g.arc(13, 12, 5, 0.3, Math.PI * 1.7); g.arc(13, 12, 2.4, Math.PI * 1.7, Math.PI * 0.4, true); g.stroke()
    }
}
