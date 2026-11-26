// CONCEPT / SPIKE popup container: short fade plus a few px slide up. UNVERIFIED until a VM run.
// Set open to show or hide. Timing comes from ElToPalette (palette/elto-palette.json, section motion).
import QtQuick

Item {
    id: root

    property bool open: false
    default property alias content: holder.data

    visible: opacity > 0
    opacity: open ? 1 : 0
    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height

    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? ElToPalette.popupMs : ElToPalette.disappearMs
            easing.type: ElToPalette.easing
        }
    }

    Item {
        id: holder
        width: parent.width
        height: parent.height
        y: root.open ? 0 : ElToPalette.popupSlidePx

        Behavior on y {
            NumberAnimation {
                duration: root.open ? ElToPalette.popupMs : ElToPalette.disappearMs
                easing.type: ElToPalette.easing
            }
        }
    }
}
