// Internal drive or USB stick drawn from theme colours; follows shape.folderArt for its fill and outline style.
import QtQuick

Item {
    id: art
    required property var th
    property bool usb: false
    readonly property string style: th.folderArt
    implicitWidth: 64; implicitHeight: usb ? 32 : 40
    width: implicitWidth; height: implicitHeight
    readonly property color body: style === "flat" ? th.surfaceAlt : Qt.tint(th.surfaceAlt, Qt.alpha(th.accent, 0.14))
    readonly property real u: width / 64
    readonly property int sw: style === "manila" ? 0 : Math.max(1, Math.round(1.5 * u))
    readonly property color strokeC: style === "glass" ? Qt.alpha(th.surface, 0.9) : th.text
    function fill(c) { return style === "outline" ? "transparent" : (style === "glass" ? Qt.alpha(c, 0.4) : c) }
    readonly property real rr: style === "flat" || style === "outline" ? 1 * u : 5 * u
    Item {
        visible: !art.usb; anchors.fill: parent
        Rectangle { x: 2*u; y: 6*u; width: 60*u; height: 30*u; radius: art.rr; color: art.fill(art.body); border.width: art.sw; border.color: art.strokeC }
        Rectangle { visible: art.style === "manila"; x: 2*u; y: 24*u; width: 60*u; height: 12*u; radius: art.rr; color: Qt.darker(art.body, 1.1) }
        Rectangle { visible: art.style === "manila"; x: 2*u; y: 24*u; width: 60*u; height: 6*u; color: Qt.darker(art.body, 1.1) }
        Rectangle { visible: art.style !== "manila"; x: 2*u; y: 24*u; width: 60*u; height: art.sw; color: art.strokeC }
        Row { x: 12*u; y: 28*u; spacing: 3*u
            Repeater { model: 5; Rectangle { width: 2*u; height: 3*u; radius: u; color: th.textMuted; opacity: 0.6 } } }
        Rectangle { x: 49.5*u; y: 27*u; width: 5*u; height: 5*u; radius: 2.5*u; color: th.textMuted }
    }
    Item {
        visible: art.usb; anchors.fill: parent
        Rectangle { x: 4*u; y: 6*u; width: 38*u; height: 20*u; radius: art.style === "flat" || art.style === "outline" ? 1*u : 6*u; color: art.fill(Qt.lighter(art.body, 1.15)); border.width: art.sw; border.color: art.strokeC }
        Rectangle { x: 40*u; y: 10*u; width: 20*u; height: 12*u; radius: 2*u; color: art.fill(Qt.darker(art.body, 1.15)); border.width: art.sw; border.color: art.strokeC }
        Rectangle { x: 46*u; y: 13*u; width: 3*u; height: 3*u; color: th.textMuted }
        Rectangle { x: 52*u; y: 13*u; width: 3*u; height: 3*u; color: th.textMuted }
        Rectangle { x: 11*u; y: 12*u; width: 12*u; height: 8*u; radius: 4*u; color: th.surface; border.width: 1; border.color: th.divider }
    }
}
