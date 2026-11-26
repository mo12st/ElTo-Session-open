// Desktop wallpaper: one background-layer window per screen. The file name comes from Theme (options.wallpaper).
// Looked up in ~/.config/elto/wallpapers/ first, then in the shipped wallpapers/ folder.
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
        readonly property string userUrl: "file://" + Quickshell.env("HOME") + "/.config/elto/wallpapers/" + Theme.wallpaper
        readonly property string shippedUrl: "file://" + Quickshell.shellPath("../wallpapers/" + Theme.wallpaper)
        Image {
            id: img
            anchors.fill: parent
            source: Quickshell.env("ELTO_WALLPAPER") ? "file://" + Quickshell.env("ELTO_WALLPAPER") : parent.userUrl
            onStatusChanged: if (status === Image.Error && !Quickshell.env("ELTO_WALLPAPER") && source === parent.userUrl) source = parent.shippedUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1200
            asynchronous: true
        }
        Connections {
            target: Theme
            function onWallpaperChanged() { if (!Quickshell.env("ELTO_WALLPAPER")) img.source = parent.userUrl }
        }
    }
}
