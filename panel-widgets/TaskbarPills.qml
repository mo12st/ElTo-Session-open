// CONCEPT / SPIKE window pills for the taskbar, UNVERIFIED until a VM run.
// Pills fade and grow in when a window opens and fade out when it closes.
// Uses Quickshell.Wayland ToplevelManager (the same source as spike/taskbar/shell.qml).
import QtQuick
import Quickshell.Wayland

ListView {
    id: root

    orientation: ListView.Horizontal
    spacing: 8
    interactive: false
    implicitHeight: 32
    implicitWidth: contentWidth
    model: ToplevelManager.toplevels

    delegate: ElToPill {
        required property var modelData
        label: modelData.title
        active: modelData.activated
        onClicked: modelData.activate()
    }

    add: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: ElToPalette.appearMs
                easing.type: ElToPalette.easing
            }
            NumberAnimation {
                property: "scale"
                from: 0.85
                to: 1
                duration: ElToPalette.appearMs
                easing.type: ElToPalette.easing
            }
        }
    }
    remove: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: ElToPalette.disappearMs
            easing.type: ElToPalette.easing
        }
    }
    displaced: Transition {
        NumberAnimation {
            properties: "x"
            duration: ElToPalette.appearMs
            easing.type: ElToPalette.easing
        }
    }
}
