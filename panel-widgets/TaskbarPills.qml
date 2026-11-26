// CONCEPT / SPIKE window pills for the taskbar, UNVERIFIED until a VM run.
// Pills fade and grow in when a window opens and fade out when it closes.
// Fed by WindowList.qml (elto-windowlist helper), because KWin does not offer foreign-toplevel.
import QtQuick

ListView {
    id: root

    orientation: ListView.Horizontal
    spacing: 8
    interactive: false
    implicitHeight: 32
    implicitWidth: contentWidth
    model: wl.model

    WindowList { id: wl }

    delegate: ElToPill {
        id: pill
        required property string uuid
        required property string title
        required property string appid
        required property bool isActive
        label: title !== "" ? title : appid
        active: isActive
        onClicked: wl.activate(uuid)

        // Fade out on close. delayRemove keeps the item alive until the fade ends.
        ListView.onRemove: SequentialAnimation {
            PropertyAction { target: pill; property: "ListView.delayRemove"; value: true }
            NumberAnimation {
                target: pill
                property: "opacity"
                to: 0
                duration: ElToPalette.disappearMs
                easing.type: ElToPalette.easing
            }
            PropertyAction { target: pill; property: "ListView.delayRemove"; value: false }
        }
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
    displaced: Transition {
        NumberAnimation {
            properties: "x"
            duration: ElToPalette.appearMs
            easing.type: ElToPalette.easing
        }
    }
}
