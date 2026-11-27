// Icon from elto-files/icons*, tinted by a theme colour (same tint method as welcome/LIcon.qml). Source SVGs are white.
// Style from the token shape.iconArt: line (default), thin, bold, pixel, gloss, ascii. Appearance only: same size and place.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root
    property string name: ""
    property color tint: "white"
    property int size: 20
    property var th: null
    readonly property string style: th ? th.iconArt : "line"
    implicitWidth: size
    implicitHeight: size
    readonly property var glyphs: ({
        "computer": "[=]", "home": "[~]", "docs": "[d]", "downloads": "[v]", "pictures": "[*]", "trash": "[x]",
        "chev-left": "<", "chev-right": ">", "close": "x", "file-pdf": "pdf", "file-text": "txt",
        "file-zip": "zip", "file-image": "img", "file-generic": "..." })
    readonly property string dir: style === "thin" ? "icons-thin" : (style === "bold" || style === "pixel" ? "icons-bold" : "icons")

    Rectangle {   // gloss: soft capsule behind the icon, a few px larger than the icon, does not change layout
        visible: root.style === "gloss"
        anchors.centerIn: parent; width: root.size + 8; height: root.size + 8; radius: height * 0.34
        border.width: 1; border.color: Qt.alpha(th ? th.surface : "white", 0.9)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(th ? th.surface : "white", 0.85) }
            GradientStop { position: 1; color: Qt.alpha(th ? th.selection : "gray", 0.45) }
        }
    }
    Image {
        id: img
        visible: false
        anchors.fill: parent
        source: root.name && root.style !== "ascii" ? "file://" + Quickshell.shellPath(root.dir + "/" + root.name + ".svg") : ""
        sourceSize.width: root.style === "pixel" ? root.size : root.size * 2
        sourceSize.height: root.style === "pixel" ? root.size : root.size * 2
        smooth: root.style !== "pixel"
        layer.enabled: root.style !== "ascii"
        layer.smooth: root.style !== "pixel"
    }
    MultiEffect {
        visible: root.style !== "ascii"
        anchors.fill: img; source: img; colorization: 1.0; colorizationColor: root.tint
    }
    Text {
        visible: root.style === "ascii"
        anchors.centerIn: parent
        text: root.glyphs[root.name] || "?"; color: root.tint
        font.family: th ? th.mono : "monospace"; font.bold: true
        font.pixelSize: Math.round(root.size * (text.length > 2 ? 0.46 : 0.68))
    }
}
