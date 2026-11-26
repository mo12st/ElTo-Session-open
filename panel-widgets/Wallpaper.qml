// CONCEPT / SPIKE wallpaper: one background-layer window per screen. Set ELTO_WALLPAPER to an image path to override.
import Quickshell
import Quickshell.Wayland
import QtQuick

Variants {
    model: Quickshell.screens
    PanelWindow {
        required property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; right: true; top: true; bottom: true }
        color: "#f6f1e4"
        Image {
            anchors.fill: parent
            source: Quickshell.env("ELTO_WALLPAPER") ? "file://" + Quickshell.env("ELTO_WALLPAPER") : "file://" + Quickshell.shellPath("../wallpaper/elto-default.svg")
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1080
        }
    }
}
