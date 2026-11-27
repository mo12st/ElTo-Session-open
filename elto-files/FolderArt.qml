// Folder drawn from theme colours. Style from the token shape.folderArt: manila (default), flat, outline, glass.
import QtQuick

Item {
    id: art
    required property var th
    readonly property string style: th.folderArt
    implicitWidth: 64; implicitHeight: 56
    width: implicitWidth; height: implicitHeight
    readonly property real u: width / 64
    readonly property color flatFill: th.folderYellow
    readonly property color body: style === "flat" ? flatFill : Qt.tint(th.surfaceAlt, Qt.alpha(th.accent, 0.14))
    readonly property color backCol: style === "flat" ? Qt.darker(flatFill, 1.15) : Qt.darker(body, 1.12)
    readonly property int sw: style === "manila" ? 0 : Math.max(1, Math.round(1.5 * u))
    readonly property color strokeC: style === "glass" ? Qt.alpha(th.surface, 0.9) : th.text
    function fill(c) { return style === "outline" ? "transparent" : (style === "glass" ? Qt.alpha(c, 0.4) : c) }
    readonly property real rr: style === "flat" || style === "outline" ? Math.min(th.radiusCard, 2) * u : th.radiusCard * 0.3 * u
    Item {
        visible: ['manila', 'flat', 'outline', 'glass'].indexOf(art.style) >= 0; anchors.fill: parent
        Rectangle { x: 5*u; y: 4*u; width: 22*u; height: 14*u; radius: art.rr; color: art.fill(art.backCol); border.width: art.sw; border.color: art.strokeC }
        Rectangle { x: 5*u; y: 8*u; width: 54*u; height: 44*u; radius: art.rr; color: art.fill(art.backCol); border.width: art.sw; border.color: art.strokeC }
        Rectangle { visible: art.style === "manila" || art.style === "glass"; x: 11*u; y: 15*u; width: 42*u; height: 24*u; radius: 2*u; color: Qt.alpha(Qt.lighter(th.surface, 1.35), art.style === "glass" ? 0.7 : 1) }
        Rectangle { visible: art.style === "manila"; x: 16*u; y: 21*u; width: 32*u; height: 1.6*u; radius: u; color: th.divider }
        Rectangle { visible: art.style === "manila"; x: 16*u; y: 26*u; width: 26*u; height: 1.6*u; radius: u; color: th.divider }
        Rectangle { x: 5*u; y: 25*u; width: 54*u; height: 27*u; radius: art.rr; color: art.fill(art.body); border.width: art.sw; border.color: art.strokeC }
        Rectangle { visible: art.style !== "flat"; x: 14*u; y: 33*u; width: 10*u; height: 5*u; radius: 2.5*u; color: th.accent }
    }

    // ---- era styles: original vector drawings (no third-party assets) ----
    readonly property color yel: flatFill
    // classic95: flat square yellow folder, dark outline, light top-left and dark bottom-right inner edge
    Item {
        visible: art.style === "classic95"; anchors.fill: parent
        Rectangle { x: 6*u; y: 8*u; width: 22*u; height: 10*u; color: Qt.darker(art.yel, 1.12); border.width: Math.max(1, u); border.color: th.text }
        Rectangle { x: 6*u; y: 16*u; width: 52*u; height: 34*u; color: art.yel; border.width: Math.max(1, u); border.color: th.text }
        Rectangle { x: 7*u; y: 17*u; width: 50*u; height: Math.max(1, u); color: Qt.lighter(art.yel, 1.6) }
        Rectangle { x: 7*u; y: 17*u; width: Math.max(1, u); height: 32*u; color: Qt.lighter(art.yel, 1.6) }
        Rectangle { x: 7*u; y: 48*u; width: 50*u; height: Math.max(1, u); color: Qt.darker(art.yel, 1.5) }
        Rectangle { x: 56*u; y: 17*u; width: Math.max(1, u); height: 32*u; color: Qt.darker(art.yel, 1.5) }
    }
    // aero: glassy rounded folder with paper behind and a gloss band
    Item {
        visible: art.style === "aero"; anchors.fill: parent
        Rectangle { x: 6*u; y: 6*u; width: 24*u; height: 12*u; radius: 4*u; color: Qt.alpha(art.yel, 0.55); border.width: 1; border.color: Qt.alpha(th.surface, 0.9) }
        Rectangle { x: 12*u; y: 12*u; width: 40*u; height: 22*u; radius: 2*u; color: Qt.alpha(Qt.lighter(th.surface, 1.3), 0.85) }
        Rectangle { x: 5*u; y: 20*u; width: 54*u; height: 32*u; radius: 5*u; border.width: 1; border.color: Qt.alpha(th.surface, 0.95)
            gradient: Gradient { GradientStop { position: 0; color: Qt.alpha(Qt.lighter(art.yel, 1.3), 0.8) } GradientStop { position: 1; color: Qt.alpha(art.yel, 0.55) } } }
        Rectangle { x: 7*u; y: 21*u; width: 50*u; height: 12*u; radius: 4*u; color: Qt.alpha(th.surface, 0.35) }
    }
    // luna: bright, soft, rounded folder with a smooth vertical gradient and a soft shadow
    Item {
        visible: art.style === "luna"; anchors.fill: parent
        Rectangle { x: 7*u; y: 49*u; width: 52*u; height: 5*u; radius: 3*u; color: Qt.alpha(th.text, 0.14) }
        Rectangle { x: 5*u; y: 8*u; width: 24*u; height: 14*u; radius: 4*u; color: Qt.darker(art.yel, 1.1) }
        Rectangle { x: 5*u; y: 16*u; width: 54*u; height: 34*u; radius: 6*u; border.width: 1; border.color: Qt.darker(art.yel, 1.45)
            gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(art.yel, 1.35) } GradientStop { position: 0.55; color: art.yel } GradientStop { position: 1; color: Qt.darker(art.yel, 1.18) } } }
        Rectangle { x: 9*u; y: 18*u; width: 46*u; height: Math.max(1, 1.5*u); radius: u; color: Qt.alpha(th.surface, 0.7) }
    }
    // chrome: brushed-metal folder with a bright highlight band and an accent tab line
    Item {
        visible: art.style === "chrome"; anchors.fill: parent
        Rectangle { x: 6*u; y: 8*u; width: 22*u; height: 12*u; radius: 3*u; color: Qt.darker(th.surfaceAlt, 1.3); border.width: 1; border.color: Qt.alpha(th.text, 0.55) }
        Rectangle { x: 6*u; y: 6*u; width: 14*u; height: Math.max(1, 1.6*u); color: th.accent }
        Rectangle { x: 5*u; y: 17*u; width: 54*u; height: 34*u; radius: 4*u; border.width: 1; border.color: Qt.alpha(th.text, 0.6)
            gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(th.surfaceAlt, 1.6) } GradientStop { position: 0.5; color: th.surfaceAlt } GradientStop { position: 0.52; color: Qt.darker(th.surfaceAlt, 1.25) } GradientStop { position: 1; color: Qt.darker(th.surfaceAlt, 1.5) } } }
    }
}
