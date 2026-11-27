// Icon drawn from icons/<dir>/. The default dir is lucide: white stroke SVGs that MultiEffect colorizes with
// a theme color. tintArt false draws the file as it is, for multi-colour artwork that must not be tinted.
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root
    property string name: ""
    property string dir: "lucide"
    property bool tintArt: true
    property color tint: Theme.text
    property int size: 20
    // a multi-colour file that is not in its folder falls back to the Lucide glyph, tinted so it stays visible
    property bool fallback: false
    implicitWidth: size
    implicitHeight: size
    Image {
        id: img
        anchors.fill: parent
        source: root.name ? "file://" + Quickshell.shellPath("../icons/" + (root.fallback ? "lucide" : root.dir) + "/" + root.name + ".svg") : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        visible: !root.tintArt || root.fallback
        layer.enabled: root.tintArt || root.fallback
        onStatusChanged: if (status === Image.Error && !root.tintArt && !root.fallback) root.fallback = true
    }
    MultiEffect {
        visible: root.tintArt || root.fallback
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: root.tint
    }
}
