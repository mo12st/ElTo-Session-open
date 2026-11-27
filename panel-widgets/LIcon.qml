// Lucide icon tinted by a theme color. Source SVGs are white; MultiEffect colorizes them.
// `dir` picks the vendored folder under icons/ (the dock uses its own set); it defaults to lucide so every
// existing caller keeps the same icon.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root
    property string name: ""
    property string dir: "lucide"
    property color tint: Theme.text
    property int size: 20
    implicitWidth: size
    implicitHeight: size
    Image {
        id: img
        anchors.fill: parent
        source: root.name ? "file://" + Quickshell.shellPath("../icons/" + root.dir + "/" + root.name + ".svg") : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: root.tint
    }
}
