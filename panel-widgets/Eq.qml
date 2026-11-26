// Tiny equalizer, three bars in the accent color. Idle when not running.
import QtQuick

Row {
    id: eq
    property bool running: false
    spacing: 3
    height: 14
    Repeater {
        model: 3
        Rectangle {
            id: bar
            required property int index
            width: 3; radius: 1.5; color: Theme.accent
            anchors.bottom: parent.bottom
            height: 5
            SequentialAnimation on height {
                running: eq.running && Theme.motion
                loops: Animation.Infinite
                NumberAnimation { to: 13 - bar.index * 2; duration: 260 + bar.index * 90; easing.type: Easing.InOutSine }
                NumberAnimation { to: 4; duration: 260 + bar.index * 70; easing.type: Easing.InOutSine }
            }
        }
    }
}
