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
    property var drawer: null
    property string npStatus: ""
    property string npTitle: ""
    property string npArtist: ""
    readonly property bool hasPlayer: npStatus !== ""
    readonly property bool playing: npStatus === "Playing"
    readonly property var nt: Theme.notchT
    readonly property int dw: nt.drawerWidth
    readonly property int pad: nt.drawerPadding
    readonly property real sw: playing ? 236 : nt.idleWidth

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

    // ---- notch modes (options.notchMode: show | hidden | auto-hide, fallback show) ----
    readonly property string mode: Theme.notchMode
    // Unknown value: warn visibly (session log), then fall back to show (Theme already did the fallback).
    readonly property string rawMode: Theme.optionsT.notchMode === undefined ? "" : String(Theme.optionsT.notchMode)
    onRawModeChanged: if (rawMode !== "" && rawMode !== mode) console.warn("ELTONOTCH unknown options.notchMode '" + rawMode + "', falling back to 'show'")
    Component.onCompleted: if (rawMode !== "" && rawMode !== mode) console.warn("ELTONOTCH unknown options.notchMode '" + rawMode + "', falling back to 'show'")
    // Fullscreen info comes from the elto-windowlist helper (no per-screen data), so it applies to all screens.
    // The helper is only started when notchRespectFullscreen is on.
    WindowList { id: wlf; enabled: Theme.notchRespectFullscreen }
    readonly property bool fsBlock: Theme.notchRespectFullscreen && wlf.fullscreenActive
    // Keyboard / script fallback: `quickshell ipc call notch reveal|toggle|status`. Always works, even in hidden mode.
    property bool kbReveal: false
    Timer { id: kbT; interval: 3000; onTriggered: root.kbReveal = false }
    IpcHandler {
        target: "notch"
        function reveal(): void { root.kbReveal = true; kbT.restart() }
        function toggle(): void {
            if (root.open || root.kbReveal) { root.open = false; root.kbReveal = false; kbT.stop() }
            else { root.kbReveal = true; kbT.stop(); root.open = true }
        }
        function status(): string { return root.mode + (root.fsBlock ? " fullscreen-blocked" : "") + (root.kbReveal ? " kb-revealed" : "") }
    }

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
            mask: Region { item: card; regions: [ Region { item: mediaHit }, Region { item: hot } ] }

            // visible state per screen
            property bool revealed: false
            readonly property bool baseShown: root.mode === "show" ? true
                : root.mode === "hidden" ? false
                : (revealed || root.open)
            readonly property bool shown: root.kbReveal || (baseShown && !root.fsBlock)

            Timer { id: closer; interval: 260; onTriggered: root.open = false }
            Timer { id: hideT; interval: Theme.notchAutoHideMs; onTriggered: win.revealed = false }
            HoverHandler {
                id: hh
                onHoveredChanged: {
                    if (hovered) {
                        closer.stop(); hideT.stop()
                        // only auto-hide tracks "revealed"; in show mode a hover must not leave it set
                        if (root.mode === "auto-hide") win.revealed = true
                        if (win.shown) root.open = true
                    } else { closer.restart(); hideT.restart() }
                }
            }
            onShownChanged: if (!shown) root.open = false

            // tuck away on start and on every mode change (stale reveal state from show mode must not survive)
            function tuck() { revealed = false; hideT.stop(); if (!hh.hovered) root.open = false }
            Component.onCompleted: tuck()
            Connections { target: root; function onModeChanged() { win.tuck() } }

            // thin hot zone at the top edge, only active while auto-hide has the notch tucked away
            Item {
                id: hot
                x: (parent.width - width) / 2; y: 0
                width: (root.mode === "auto-hide" && !win.shown && !root.fsBlock) ? root.sw + 60 : 0
                height: width > 0 ? 5 : 0
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
                y: win.shown ? -30 : -(height + 50)
                Behavior on y { NumberAnimation { duration: Theme.ms(root.nt.openMs); easing.type: Easing.OutCubic } }
                width: root.open ? root.dw : root.sw
                height: (root.open ? drawer.implicitHeight + 30 : root.nt.idleHeight + 30)
                radius: root.open ? root.nt.drawerRadius : root.nt.idleHeight / 2 + 2
                color: Theme.surface
                clip: true
                Behavior on width { NumberAnimation { duration: Theme.ms(root.nt.openMs); easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Theme.ms(root.nt.openMs); easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: Theme.ms(root.nt.openMs); easing.type: Easing.OutCubic } }

                // idle notch row
                Row {
                    id: idle
                    y: 30 + (root.nt.idleHeight - height) / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    opacity: root.open ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(150) } }
                    Image {
                        source: "file://" + Quickshell.shellPath("../lock/assets/snail.png")
                        height: 22; width: 22; fillMode: Image.PreserveAspectFit; smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: if (root.drawer) { root.drawer.toggle(); root.open = false } }
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
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(root.nt.openMs); easing.type: Easing.OutCubic } }

                    Item {
                        width: parent.width
                        Image {
                            source: "file://" + Quickshell.shellPath("../lock/assets/snail.png")
                            x: 0; y: 6; width: 30; height: 30; fillMode: Image.PreserveAspectFit; smooth: true
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: if (root.drawer) { root.drawer.toggle(); root.open = false } }
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
                            color: Theme.textMuted; font.family: Theme.serif; font.italic: true; font.pixelSize: 14
                            renderType: Text.NativeRendering
                        }
                        height: 76
                    }

                    Grid {
                        columns: 2
                        spacing: root.nt.gap
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
                                width: (drawer.width - root.nt.gap) / 2
                                height: root.nt.toggleHeight
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
                width: (root.hasPlayer && win.shown) ? 380 : 0
                height: (root.hasPlayer && win.shown) ? root.nt.mediaHeight : 0
                Behavior on y { NumberAnimation { duration: Theme.ms(root.nt.openMs); easing.type: Easing.OutCubic } }
                opacity: (root.hasPlayer && win.shown) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.ms(root.nt.openMs) } }
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
                            font.family: Theme.serif; font.italic: true; font.pixelSize: 19; renderType: Text.NativeRendering }
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
