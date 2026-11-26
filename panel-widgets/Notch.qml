// ElTo mix notch (CONCEPT until approved): small clock notch at top center, hover opens a quick-settings drawer.
// A media card shows under it when an MPRIS player exists. All look values come from Theme (theme.json).
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Scope {
    id: root
    property bool open: false
    property string npStatus: ""
    property string npTitle: ""
    property string npArtist: ""
    readonly property bool hasPlayer: npStatus !== ""
    readonly property bool playing: npStatus === "Playing"
    readonly property var N: Theme.notchT
    readonly property int dw: N.drawerWidth
    readonly property int pad: N.drawerPadding
    readonly property real sw: playing ? 236 : N.idleWidth

    // ---- media via playerctl (MPRIS) ----
    Process {
        id: pc
        command: ["playerctl", "metadata", "--format", "{{status}}|{{title}}|{{artist}}"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("|")
                if (p.length >= 3) { root.npStatus = p[0]; root.npTitle = p[1]; root.npArtist = p.slice(2).join("|") }
                else { root.npStatus = ""; root.npTitle = ""; root.npArtist = "" }
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!pc.running) pc.running = true }
    Process { id: pcCtl }
    function media(cmd) { pcCtl.command = ["playerctl", cmd]; pcCtl.running = true; pc.running = true }

    // ---- volume (Pipewire) ----
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: sink !== null && sink.audio !== null
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    property real lightValue: 0.8
    property var toggles: ({ wifi: true, sound: true, night: false, quiet: false })

    SystemClock { id: clk; precision: SystemClock.Minutes }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "elto-notch"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true }
            implicitWidth: root.dw + 40
            implicitHeight: 460
            color: "transparent"
            mask: Region { item: card; regions: [ Region { item: mediaHit } ] }

            Timer { id: closer; interval: 260; onTriggered: root.open = false }
            HoverHandler {
                id: hh
                onHoveredChanged: { if (hovered) { closer.stop(); root.open = true } else closer.restart() }
            }

            // soft shadow: stacked translucent rounded shapes
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: card.x - index * 2; y: card.y + Theme.shadowOffsetY / 3 - index * 1
                    width: card.width + index * 4; height: card.height + index * 4
                    radius: card.radius + index * 2
                    color: Qt.rgba(0, 0, 0, Theme.shadowAlpha / 18)
                }
            }

            Rectangle {
                id: card
                x: (parent.width - width) / 2
                y: -30
                width: root.open ? root.dw : root.sw
                height: (root.open ? drawer.implicitHeight + 30 : root.N.idleHeight + 30)
                radius: root.open ? root.N.drawerRadius : root.N.idleHeight / 2 + 2
                color: Theme.surface
                clip: true
                Behavior on width { NumberAnimation { duration: Theme.ms(root.N.openMs); easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Theme.ms(root.N.openMs); easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: Theme.ms(root.N.openMs); easing.type: Easing.OutCubic } }

                // idle notch row
                Row {
                    id: idle
                    y: 30 + (root.N.idleHeight - height) / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    opacity: root.open ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(150) } }
                    Image {
                        source: "file://" + Quickshell.shellPath("../lock/assets/snail.png")
                        height: 22; width: 22; fillMode: Image.PreserveAspectFit; smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clk.date, "hh:mm")
                        color: Theme.textMuted; font.family: Theme.serif; font.pixelSize: 18
                        renderType: Text.NativeRendering
                    }
                    Row {
                        visible: root.playing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Eq { anchors.verticalCenter: parent.verticalCenter; running: root.playing }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 90; elide: Text.ElideRight
                            text: root.npTitle; color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        visible: !root.playing
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 4; color: Theme.accent
                    }
                }

                // drawer
                Column {
                    id: drawer
                    y: 30
                    x: root.pad
                    width: root.dw - root.pad * 2
                    spacing: 16
                    topPadding: root.pad - 6
                    bottomPadding: root.pad
                    opacity: root.open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(root.N.openMs); easing.type: Easing.OutCubic } }

                    Item {
                        width: parent.width
                        Image {
                            source: "file://" + Quickshell.shellPath("../lock/assets/snail.png")
                            x: 0; y: 6; width: 30; height: 30; fillMode: Image.PreserveAspectFit; smooth: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clk.date, "hh:mm")
                            color: Theme.text; font.family: Theme.serif; font.pixelSize: 44
                            renderType: Text.NativeRendering
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 50
                            text: Qt.formatDateTime(clk.date, "dddd, d MMMM")
                            color: Theme.textMuted; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 14
                            renderType: Text.NativeRendering
                        }
                        height: 76
                    }

                    Grid {
                        columns: 2
                        spacing: root.N.gap
                        width: parent.width
                        Repeater {
                            model: [
                                { key: "wifi", icon: "wifi", label: "Wi-Fi" },
                                { key: "sound", icon: "volume-2", label: "Sound" },
                                { key: "night", icon: "moon", label: "Night" },
                                { key: "quiet", icon: "bell-off", label: "Quiet" }
                            ]
                            Rectangle {
                                required property var modelData
                                readonly property bool on: root.toggles[modelData.key]
                                width: (drawer.width - root.N.gap) / 2
                                height: root.N.toggleHeight
                                radius: height / 2
                                color: on ? Theme.color("midGreen") : Theme.surfaceAlt
                                Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    LIcon { name: modelData.icon; size: 18; tint: on ? Theme.surface : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label; font.family: Theme.sans; font.pixelSize: 14
                                        color: on ? Theme.surface : Theme.text
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { var t = root.toggles; t[modelData.key] = !t[modelData.key]; root.toggles = Object.assign({}, t) }
                                }
                            }
                        }
                    }

                    Slider { width: parent.width; icon: "volume-2"; enabledSlider: root.sinkReady
                        value: root.sinkReady ? root.sink.audio.volume : 0
                        onMoved: v => { if (root.sinkReady) root.sink.audio.volume = v } }
                    Slider { width: parent.width; icon: "sun"; enabledSlider: true
                        value: root.lightValue; onMoved: v => root.lightValue = v }
                }
            }

            // media card under the notch
            Item {
                id: mediaHit
                x: card.x + (card.width - width) / 2
                y: card.y + card.height + 10
                width: root.hasPlayer ? 380 : 0
                height: root.hasPlayer ? root.N.mediaHeight : 0
                Behavior on y { NumberAnimation { duration: Theme.ms(root.N.openMs); easing.type: Easing.OutCubic } }
                opacity: root.hasPlayer ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.ms(root.N.openMs) } }
                Rectangle {
                    anchors.fill: parent; radius: 24; color: Theme.surface
                    Rectangle {
                        id: art; x: 14; y: 14; width: parent.height - 28; height: width; radius: 14; color: Theme.color("midGreen")
                        Image {
                            anchors.centerIn: parent; width: parent.width * 0.7; height: width
                            source: "file://" + Quickshell.shellPath("../lock/assets/snail.png"); fillMode: Image.PreserveAspectFit; smooth: true
                        }
                    }
                    Column {
                        x: art.x + art.width + 14; y: 14; width: parent.width - x - 14 - 100
                        spacing: 2
                        Text { text: root.playing ? "Now playing" : "Paused"; color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 11 }
                        Text { width: parent.width; elide: Text.ElideRight; text: root.npTitle; color: Theme.text
                            font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 19; renderType: Text.NativeRendering }
                        Text { width: parent.width; elide: Text.ElideRight; text: root.npArtist; color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 12 }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        LIcon { name: "skip-back"; size: 18; tint: Theme.text; anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.media("previous") } }
                        Rectangle {
                            width: 36; height: 36; radius: 18; color: Theme.color("midGreen"); anchors.verticalCenter: parent.verticalCenter
                            LIcon { anchors.centerIn: parent; name: root.playing ? "pause" : "play"; size: 18; tint: Theme.surface }
                            MouseArea { anchors.fill: parent; onClicked: root.media("play-pause") }
                        }
                        LIcon { name: "skip-forward"; size: 18; tint: Theme.text; anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.media("next") } }
                    }
                }
            }
        }
    }
}
