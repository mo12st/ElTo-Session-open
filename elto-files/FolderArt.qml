// Folder drawn from theme colours. Style from the token shape.folderArt: manila (default), flat, outline, glass.
import QtQuick

Item {
    id: art
    required property var th
    readonly property string style: th.folderArt
    implicitWidth: 64; implicitHeight: 56
    width: implicitWidth; height: implicitHeight
    readonly property real u: width / 64
    readonly property color flatFill: th.colors.windowMinimize !== undefined ? th.colors.windowMinimize : th.accent
    readonly property color body: style === "flat" ? flatFill : Qt.tint(th.surfaceAlt, Qt.alpha(th.accent, 0.14))
    readonly property color backCol: style === "flat" ? Qt.darker(flatFill, 1.15) : Qt.darker(body, 1.12)
    readonly property int sw: style === "manila" ? 0 : Math.max(1, Math.round(1.5 * u))
    readonly property color strokeC: style === "glass" ? Qt.alpha(th.surface, 0.9) : th.text
    function fill(c) { return style === "outline" ? "transparent" : (style === "glass" ? Qt.alpha(c, 0.4) : c) }
    readonly property real rr: style === "flat" || style === "outline" ? Math.min(th.radiusCard, 2) * u : th.radiusCard * 0.3 * u
    Rectangle { x: 5*u; y: 4*u; width: 22*u; height: 14*u; radius: art.rr; color: art.fill(art.backCol); border.width: art.sw; border.color: art.strokeC }
    Rectangle { x: 5*u; y: 8*u; width: 54*u; height: 44*u; radius: art.rr; color: art.fill(art.backCol); border.width: art.sw; border.color: art.strokeC }
    Rectangle { visible: art.style === "manila" || art.style === "glass"; x: 11*u; y: 15*u; width: 42*u; height: 24*u; radius: 2*u; color: Qt.alpha(Qt.lighter(th.surface, 1.35), art.style === "glass" ? 0.7 : 1) }
    Rectangle { visible: art.style === "manila"; x: 16*u; y: 21*u; width: 32*u; height: 1.6*u; radius: u; color: th.divider }
    Rectangle { visible: art.style === "manila"; x: 16*u; y: 26*u; width: 26*u; height: 1.6*u; radius: u; color: th.divider }
    Rectangle { x: 5*u; y: 25*u; width: 54*u; height: 27*u; radius: art.rr; color: art.fill(art.body); border.width: art.sw; border.color: art.strokeC }
    Rectangle { visible: art.style !== "flat"; x: 14*u; y: 33*u; width: 10*u; height: 5*u; radius: 2.5*u; color: th.accent }
}
