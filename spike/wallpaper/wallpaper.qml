// SPIKE: draws an image on the background layer. Run: WALLPAPER=/path quickshell -p wallpaper.qml
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; right: true; top: true; bottom: true }
        color: "#000000"
        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("WALLPAPER")
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1080
        }
    }
}
