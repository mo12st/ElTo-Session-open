// Icon tinted by a theme color. Same behavior as panel-widgets/LIcon.qml, but the icon
// directory is a property so Control can use its own icons (elto-control/icons/) as well as
// the shell set (../icons/lucide/) without adding files to another track's directory.
import QtQuick
import QtQuick.Effects
import Quickshell
import "../panel-widgets"

Item {
    id: root

    property string name: ""
    // Relative to this file: "icons" for Control's own set, "../icons/lucide" for the shell set.
    property string dir: "icons"
    property color tint: Theme.text
    property int size: 20

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? "file://" + Quickshell.shellPath(root.dir + "/" + root.name + ".svg") : ""
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
