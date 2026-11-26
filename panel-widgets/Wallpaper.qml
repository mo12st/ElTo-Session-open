// Desktop wallpaper: one background-layer window per screen. The file name comes from Theme (options.wallpaper).
// ~/.config/elto/wallpapers/<name> wins when it exists, otherwise the shipped wallpapers/<name> shows.
// ELTO_WALLPAPER (full path) still overrides, for testing.
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
        color: Theme.surface
        Image {
            anchors.fill: parent
            source: Quickshell.env("ELTO_WALLPAPER") ? "file://" + Quickshell.env("ELTO_WALLPAPER")
                  : "file://" + Quickshell.shellPath("../wallpapers/" + Theme.wallpaper)
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1200
            asynchronous: true
        }
        Image {
            anchors.fill: parent
            visible: status === Image.Ready
            source: Quickshell.env("ELTO_WALLPAPER") ? "" : "file://" + Quickshell.env("HOME") + "/.config/elto/wallpapers/" + Theme.wallpaper
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1200
            asynchronous: true
        }
    }
}
