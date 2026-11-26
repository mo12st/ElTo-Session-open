// Dock window plus a compositor blur request behind the bar. Loads only when dock.blur is on; if the type is missing it fails and the dock falls back.
import Quickshell
import Quickshell.Wayland

DockWindow {
    BackgroundEffect.blurRegion: Region { item: bar }
    Component.onCompleted: console.log("ELTODOCKBLUR requested")
}
