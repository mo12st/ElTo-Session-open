// Theme-driven slider row: icon, 6 px track, 14 px knob, percent value.
import QtQuick

Item {
    id: s
    property string icon: ""
    property real value: 0.5
    property bool enabledSlider: true
    signal moved(real v)
    height: 30
    LIcon { id: ic; name: s.icon; size: 18; tint: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
    Item {
        id: track
        x: 30; width: parent.width - 30 - 44; height: parent.height
        Rectangle { y: (parent.height - height) / 2; width: parent.width; height: Theme.notchT.sliderTrack; radius: height / 2; color: Theme.surfaceAlt }
        Rectangle { y: (parent.height - height) / 2; width: parent.width * s.value; height: Theme.notchT.sliderTrack; radius: height / 2; color: Theme.color("midGreen") }
        Rectangle {
            x: Math.max(0, Math.min(parent.width, parent.width * s.value)) - width / 2
            y: (parent.height - height) / 2
            width: Theme.notchT.sliderKnob; height: width; radius: width / 2
            color: s.enabledSlider ? Theme.accent : Theme.disabled
        }
        MouseArea {
            anchors.fill: parent; enabled: s.enabledSlider
            onPressed: m => s.moved(Math.max(0, Math.min(1, m.x / width)))
            onPositionChanged: m => { if (pressed) s.moved(Math.max(0, Math.min(1, m.x / width))) }
        }
    }
    Text {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: s.enabledSlider ? Math.round(s.value * 100) + "%" : "--"
        color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 12
    }
}
