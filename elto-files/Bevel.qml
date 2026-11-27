// Classic raised or inset bevel edge, drawn only when the theme token shape.bevel > 0 (Win95, Retro 95 worlds).
import QtQuick

Item {
    id: bv
    required property var th
    property bool raised: true
    readonly property int b: th.bevel
    anchors.fill: parent
    visible: b > 0
    readonly property color hi: Qt.lighter(th.surface, 1.7)
    readonly property color lo: Qt.darker(th.surface, 2.0)
    readonly property color topLeft: raised ? hi : lo
    readonly property color bottomRight: raised ? lo : hi
    Rectangle { x: 0; y: 0; width: bv.width; height: bv.b; color: bv.topLeft }
    Rectangle { x: 0; y: 0; width: bv.b; height: bv.height; color: bv.topLeft }
    Rectangle { x: 0; y: bv.height - bv.b; width: bv.width; height: bv.b; color: bv.bottomRight }
    Rectangle { x: bv.width - bv.b; y: 0; width: bv.b; height: bv.height; color: bv.bottomRight }
}
