// Mono icon from elto-files/icons, tinted by a theme colour (same method as welcome/LIcon.qml). Source SVGs are white.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root
    property string name: ""
    property color tint: "white"
    property int size: 20
    implicitWidth: size
    implicitHeight: size
    Image {
        id: img
        anchors.fill: parent
        source: root.name ? "file://" + Quickshell.shellPath("icons/" + root.name + ".svg") : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        visible: false
        layer.enabled: true
    }
    MultiEffect { anchors.fill: img; source: img; colorization: 1.0; colorizationColor: root.tint }
}
