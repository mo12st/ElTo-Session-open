import Quickshell
import Quickshell.Wayland
import QtQuick
ShellRoot {
  id: root
  property int tl: ToplevelManager.toplevels.values.length
  onTlChanged: console.log("SPIKE toplevels=" + tl)
  Component.onCompleted: console.log("SPIKE shell started")
  PanelWindow {
    id: bg
    Timer { interval: 7000; running: true; onTriggered: bgr.grabToImage(function(r){ console.log("SPIKE grab bg " + r.saveToFile("/tmp/qs-bg.png") + " " + r.image.width + "x" + r.image.height) }) }
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    color: "#efe9d8"
    Rectangle { id: bgr; anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#cfe3d4" } GradientStop { position: 1; color: "#f4ecd6" } } }
    Text { x: 60; y: 50; text: "ElTo"; font.pixelSize: 64; font.family: "serif"; color: "#283a32" }
    Text { x: 60; y: 130; text: "SPIKE: Quickshell on KWin (not a design)"; font.pixelSize: 22; color: "#4c7860" }
  }
  PanelWindow {
    id: panel
    Timer { interval: 7500; running: true; onTriggered: panelr.grabToImage(function(r){ console.log("SPIKE grab panel " + r.saveToFile("/tmp/qs-panel.png") + " " + r.image.width + "x" + r.image.height) }) }
    anchors { left: true; right: true; bottom: true }
    implicitHeight: 70
    color: "#f6f1e4"
    Rectangle { id: panelr; anchors.fill: parent; color: "#f6f1e4"; z: -1 }
    Text { anchors.centerIn: parent; font.pixelSize: 26; color: "#283a32"
           text: "SPIKE panel. Windows seen via foreign-toplevel: " + root.tl }
    Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 } font.pixelSize: 20; color: "#a05040"; text: "CONCEPT-SPIKE" }
  }
}
