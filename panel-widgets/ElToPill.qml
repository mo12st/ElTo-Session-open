// CONCEPT / SPIKE taskbar pill with light animations, UNVERIFIED until a VM run.
// All durations and easing come from ElToPalette (palette/elto-palette.json, section motion).
import QtQuick

Rectangle {
    id: root

    property string label: ""
    property bool active: false
    signal clicked

    implicitWidth: text.implicitWidth + 28
    implicitHeight: 32
    radius: height / 2
    color: active ? ElToPalette.lightGreen : (area.containsMouse ? ElToPalette.creamDark : ElToPalette.cream)
    border.width: 1
    border.color: active ? ElToPalette.midGreen : ElToPalette.inactiveBg
    scale: area.pressed ? 0.96 : 1.0

    Behavior on color {
        ColorAnimation {
            duration: root.active ? ElToPalette.activeMs : ElToPalette.hoverMs
            easing.type: ElToPalette.easing
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: ElToPalette.activeMs
            easing.type: ElToPalette.easing
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: ElToPalette.pressMs
            easing.type: ElToPalette.easing
        }
    }

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        color: ElToPalette.text
        font.pixelSize: 16
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
