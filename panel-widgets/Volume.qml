// CONCEPT / SPIKE widget, not a design. Quickshell.Services.Pipewire only, no Plasma imports.
// Click toggles mute, wheel changes volume in 5% steps.
import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    property color textColor: "#283a32"
    property int pixelSize: 20
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null

    // Pipewire nodes only expose audio properties while tracked.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        color: root.textColor
        font.pixelSize: root.pixelSize
        text: !root.ready ? "vol --"
            : root.sink.audio.muted ? "vol muted"
            : "vol " + Math.round(root.sink.audio.volume * 100) + "%"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.ready)
                root.sink.audio.muted = !root.sink.audio.muted;
        }
        onWheel: wheel => {
            if (!root.ready)
                return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
