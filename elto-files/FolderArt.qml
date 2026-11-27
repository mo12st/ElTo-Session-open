// Manila folder drawn from theme colours (no fixed hex): body is surfaceAlt warmed by the accent, label is the accent.
import QtQuick

Item {
    id: art
    required property var th
    implicitWidth: 64; implicitHeight: 56
    width: implicitWidth; height: implicitHeight
    readonly property color body: Qt.tint(th.surfaceAlt, Qt.alpha(th.accent, 0.14))
    readonly property color backCol: Qt.darker(body, 1.12)
    readonly property real u: width / 64
    Rectangle { x: 5*u; y: 4*u; width: 22*u; height: 14*u; radius: th.radiusCard * 0.3 * u; color: art.backCol }
    Rectangle { x: 5*u; y: 8*u; width: 54*u; height: 44*u; radius: th.radiusCard * 0.3 * u; color: art.backCol }
    Rectangle { x: 11*u; y: 15*u; width: 42*u; height: 24*u; radius: 2*u; color: Qt.lighter(th.surface, 1.35) }
    Rectangle { x: 16*u; y: 21*u; width: 32*u; height: 1.6*u; radius: u; color: th.divider }
    Rectangle { x: 16*u; y: 26*u; width: 26*u; height: 1.6*u; radius: u; color: th.divider }
    Rectangle { x: 5*u; y: 25*u; width: 54*u; height: 27*u; radius: th.radiusCard * 0.3 * u; color: art.body }
    Rectangle { x: 14*u; y: 33*u; width: 10*u; height: 5*u; radius: 2.5*u; color: th.accent }
}
