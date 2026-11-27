// Dock bar plus a compositor blur request behind the strip. Loads only when dock.blur is on; if the
// BackgroundEffect type is missing this file fails to load and Dock.qml falls back to the plain bar.
import Quickshell
import Quickshell.Wayland

DockBar {
    BackgroundEffect.blurRegion: Region { item: bar }
    Component.onCompleted: console.log("ELTODOCKBLUR requested (bar)")
}
