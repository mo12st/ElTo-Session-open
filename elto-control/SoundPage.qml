// Sound page: PipeWire only (Quickshell.Services.Pipewire, the same import Volume.qml uses)
// for state; `wpctl` (ships with pipewire) for switching the default output. No daemon added.
// Condition: when PipeWire is down or no sink exists, the page says so instead of faking controls.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: page
    anchors.fill: parent

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null

    // Output devices: audio sinks that are not app streams.
    readonly property var outputs: {
        var out = []
        var list = Pipewire.nodes.values
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            if (n.isSink && !n.isStream && n.audio)
                out.push(n)
        }
        return out
    }

    // Pipewire nodes only expose audio properties while tracked (pattern from Volume.qml).
    PwObjectTracker { objects: Pipewire.nodes.values }

    property string lastError: ""

    Process {
        id: setDefault
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.lastError = text.trim() }
        }
    }

    Column {
        x: 28; y: 4; width: parent.width - 56; spacing: 10

        // ---- unavailable state (no fake controls)
        Rectangle {
            visible: !page.ready
            width: parent.width; height: 60; radius: Theme.radiusCard; color: Theme.surfaceAlt
            Text {
                anchors.centerIn: parent
                text: I18n.t("soundUnavailable")
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 14
            }
        }

        // ---- output device
        Text {
            visible: page.ready
            text: I18n.t("outputDevice")
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22
            renderType: Text.NativeRendering
        }
        Repeater {
            model: page.ready ? page.outputs : []
            ElRow {
                required property var modelData
                readonly property bool isDefault: page.sink !== null && modelData.id === page.sink.id
                width: parent.width
                title: modelData.description || modelData.name
                subtitle: isDefault ? I18n.t("defaultDevice") : ""
                Rectangle {
                    visible: isDefault
                    width: 22; height: 22; radius: 11; color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "✓"; color: Theme.surface; font.pixelSize: 13; font.bold: true }
                }
                ElButton {
                    visible: !isDefault
                    text: I18n.t("connect")
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        page.lastError = ""
                        setDefault.command = ["wpctl", "set-default", String(modelData.id)]
                        setDefault.running = true
                    }
                }
            }
        }

        // ---- volume and mute of the default output (proven Volume.qml pattern)
        ElRow {
            visible: page.ready
            width: parent.width
            title: I18n.t("volume")
            subtitle: page.ready ? Math.round(page.sink.audio.volume * 100) + "%" : ""
            Item {
                width: 200; height: 26
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { y: 10; width: parent.width; height: 6; radius: 3; color: Theme.divider }
                Rectangle {
                    y: 10; radius: 3; height: 6; color: Theme.color("midGreen")
                    width: page.ready ? parent.width * Math.min(1, page.sink.audio.volume) : 0
                }
                Rectangle {
                    y: 6; width: 14; height: 14; radius: 7; color: Theme.accent
                    x: page.ready ? parent.width * Math.min(1, page.sink.audio.volume) - 7 : -7
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: m => { if (page.ready) page.sink.audio.volume = Math.max(0, Math.min(1, m.x / width)) }
                    onPositionChanged: m => { if (page.ready && m.buttons & Qt.LeftButton) page.sink.audio.volume = Math.max(0, Math.min(1, m.x / width)) }
                }
            }
        }

        ElRow {
            visible: page.ready
            width: parent.width
            title: I18n.t("mute")
            ElToggle {
                checked: page.ready ? page.sink.audio.muted : false
                onToggled: if (page.ready) page.sink.audio.muted = !page.sink.audio.muted
            }
        }

        Text {
            visible: page.lastError !== ""
            text: I18n.t("actionFailed") + ": " + page.lastError
            color: Theme.color("rust"); font.family: Theme.sans; font.pixelSize: 13
            width: parent.width; wrapMode: Text.Wrap
        }
    }
}
