import QtQuick
import QtQuick.Controls as QQC2

// ElTo lock screen, layout B (CONCEPT, approved in principle by the owner; VM-proven only, not hardware).
// Centered serif clock + date, password field with the snail, now-playing card (playerctl/MPRIS),
// Sleep / Restart / Shut down buttons.
Item {
    id: root
    property bool locked: false
    property bool capsLockOn: false
    signal unlockRequested()

    // ---- ONE-LINE BACKGROUND SWITCH: "aquarelle" (B2, default) or "dusk" (B3) ----
    property string background: "aquarelle"

    readonly property bool dusk: background === "dusk"
    readonly property string cream: "#f6f1e4"
    readonly property string green: "#283a32"
    readonly property string mid: "#4c7860"
    readonly property string rust: "#a05040"
    readonly property string serif: "Noto Serif Display"
    readonly property color ink: dusk ? cream : green
    readonly property color soft: dusk ? "#cfe3d4" : "#4c7860"
    property real k: Math.min(width / 1280, height / 800)

    // ---- background ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: root.dusk ? "#1d2b25" : "#f4f1e8" }
            GradientStop { position: 1; color: root.dusk ? "#2d4a3c" : "#e8e2cf" }
        }
    }
    Image {
        anchors.fill: parent
        visible: !root.dusk
        source: Qt.resolvedUrl("assets/Background.png")
        fillMode: Image.PreserveAspectCrop
    }
    Repeater {   // stars (dusk only)
        model: root.dusk ? 46 : 0
        Rectangle {
            property real r: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
            property real r2: Math.abs(Math.sin(index * 78.233) * 12345.6789) % 1
            x: r * root.width; y: r2 * root.height * 0.55
            width: (index % 5 === 0 ? 3 : 2) * root.k; height: width; radius: width / 2
            color: root.cream; opacity: 0.35 + (index % 4) * 0.15
        }
    }
    Rectangle {  // moon (dusk only)
        visible: root.dusk
        width: 90 * root.k; height: width; radius: width / 2
        x: root.width * 0.8; y: root.height * 0.12
        color: root.cream
    }
    Canvas {
        id: hills
        anchors.fill: parent
        property bool dusk: root.dusk
        onDuskChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset()
            var W = width, H = height
            function hill(y0, amp, ph, col) {
                c.beginPath(); c.moveTo(0, H)
                for (var x = 0; x <= W; x += 8) c.lineTo(x, y0 + amp * Math.sin(x / W * 6.28 * 0.9 + ph))
                c.lineTo(W, H); c.closePath(); c.fillStyle = col; c.fill()
            }
            if (dusk) {
                hill(H * 0.76, H * 0.035, 0.6, "#3a5f4c")
                hill(H * 0.86, H * 0.03, 2.0, "#283a32")
            } else {
                hill(H * 0.78, H * 0.03, 0.6, "#8aa898")
                hill(H * 0.88, H * 0.025, 2.0, "#4c7860")
            }
        }
    }

    // ---- clock + date ----
    property string timeText: ""
    property string dateText: ""
    function tick() {
        var d = new Date()
        timeText = Qt.formatTime(d, "hh:mm")
        dateText = Qt.formatDate(d, "dddd, d MMMM")
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }
    Column {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.17
        spacing: 6 * root.k
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText; color: root.ink
            font.family: root.serif; font.pixelSize: 150 * root.k; renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateText; color: root.soft
            font.family: root.serif; font.italic: true; font.pixelSize: 30 * root.k; renderType: Text.NativeRendering
        }
        Item { width: 1; height: 26 * root.k }
        // password field with the snail inside
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 380 * root.k; height: 56 * root.k; radius: height / 2
            color: "#ecf6f1e4"
            border.color: pw.activeFocus ? root.rust : (root.dusk ? "#88cfe3d4" : "#8a9a90"); border.width: 2
            Image {
                id: snail
                source: Qt.resolvedUrl("assets/snail.png")
                height: 38 * root.k; width: height * 360 / 272
                x: 16 * root.k; anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                
            }
            TextInput {
                id: pw
                anchors { left: snail.right; leftMargin: 14 * root.k; right: parent.right; rightMargin: 22 * root.k; verticalCenter: parent.verticalCenter }
                echoMode: TextInput.Password; passwordCharacter: "\u2022"
                color: root.green; font.pixelSize: 22 * root.k; font.family: "Noto Sans"
                clip: true; focus: true
                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
            }
            Text {
                anchors { left: pw.left; verticalCenter: parent.verticalCenter }
                visible: pw.text.length === 0
                text: "Password"; color: "#8a9a90"
                font.pixelSize: 22 * root.k; font.family: "Noto Sans"
            }
        }
        Text {
            id: note
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.capsLockOn && note.msg === "" ? "Caps Lock is on" : note.msg
            property string msg: ""
            color: root.dusk ? "#e8a090" : root.rust
            font.pixelSize: 18 * root.k; font.family: "Noto Sans"
        }
    }
    function submit() { console.log("ELTOLOCK enter len=" + pw.text.length); authenticator.respond(pw.text) }
    Connections {
        target: authenticator
        function onFailed(kind) { if (kind !== 0) return; note.msg = "Unlocking failed"; pw.text = ""; console.log("ELTOLOCK failed"); authenticator.startAuthenticating() }
        function onSucceeded() { console.log("ELTOLOCK succeeded"); authenticator.stopAuthenticating(); Qt.quit() }
    }
    Timer { interval: 1000; running: !authenticator.unlocked; repeat: true; onTriggered: authenticator.startAuthenticating() }

    // ---- command runner (media + power) ----
    Loader {
        id: exec
        source: "Exec.qml"
        onStatusChanged: console.log("ELTOLOCK exec status " + status)
    }
    function sh(cmd, cb) {
        if (exec.status !== Loader.Ready) { console.log("ELTOLOCK exec unavailable for: " + cmd); return }
        console.log("ELTOLOCK run: " + cmd)
        exec.item.run(cmd, cb)
    }

    // ---- now playing (playerctl talks MPRIS) ----
    property string npStatus: ""
    property string npTitle: ""
    property string npArtist: ""
    property bool hasPlayer: npStatus !== ""
    Timer {
        interval: 2000; running: exec.status === Loader.Ready; repeat: true; triggeredOnStart: true
        onTriggered: root.sh("playerctl metadata --format '{{status}}|{{title}}|{{artist}}' 2>/dev/null; true", function (out) {
            var p = out.split("|")
            if (p.length >= 3) { root.npStatus = p[0]; root.npTitle = p[1]; root.npArtist = p.slice(2).join("|") }
            else { root.npStatus = ""; root.npTitle = ""; root.npArtist = "" }
        })
    }
    Rectangle {
        id: media
        x: 40 * root.k; y: root.height - height - 40 * root.k
        width: 380 * root.k; height: 96 * root.k; radius: 18 * root.k
        color: root.dusk ? "#2effffff" : "#ddf6f1e4"
        border.color: root.dusk ? "#55cfe3d4" : "#8a9a90"; border.width: 1
        Rectangle {
            id: art
            x: 14 * root.k; anchors.verticalCenter: parent.verticalCenter
            width: 68 * root.k; height: width; radius: 10 * root.k; color: root.mid
            Text { anchors.centerIn: parent; text: "\u266A"; color: root.cream; font.pixelSize: 34 * root.k }
        }
        Column {
            x: 96 * root.k; y: 14 * root.k; width: parent.width - 110 * root.k; spacing: 2 * root.k
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.hasPlayer ? root.npTitle : "Nothing playing"
                color: root.ink; font.pixelSize: 19 * root.k; font.family: "Noto Sans"; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.hasPlayer ? root.npArtist : "No media player is running"
                color: root.soft; font.pixelSize: 15 * root.k; font.family: "Noto Sans"
            }
        }
        Row {
            x: 96 * root.k; y: parent.height - 38 * root.k; spacing: 14 * root.k
            opacity: root.hasPlayer ? 1 : 0.35
            Repeater {
                model: ["prev", "play", "next"]
                Rectangle {
                    width: 30 * root.k; height: width; radius: width / 2
                    color: ma.containsMouse && root.hasPlayer ? root.mid : "transparent"
                    Canvas {
                        anchors.fill: parent
                        property bool playing: root.npStatus === "Playing"
                        onPlayingChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset(); c.fillStyle = root.ink
                            var w = width, h = height, m = modelData
                            if (m === "play" && playing) { c.fillRect(w*0.32, h*0.28, w*0.13, h*0.44); c.fillRect(w*0.55, h*0.28, w*0.13, h*0.44) }
                            else if (m === "play") { c.beginPath(); c.moveTo(w*0.36, h*0.26); c.lineTo(w*0.72, h*0.5); c.lineTo(w*0.36, h*0.74); c.closePath(); c.fill() }
                            else if (m === "next") { c.beginPath(); c.moveTo(w*0.28, h*0.28); c.lineTo(w*0.58, h*0.5); c.lineTo(w*0.28, h*0.72); c.closePath(); c.fill(); c.fillRect(w*0.62, h*0.28, w*0.08, h*0.44) }
                            else { c.beginPath(); c.moveTo(w*0.72, h*0.28); c.lineTo(w*0.42, h*0.5); c.lineTo(w*0.72, h*0.72); c.closePath(); c.fill(); c.fillRect(w*0.30, h*0.28, w*0.08, h*0.44) }
                        }
                    }
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true
                        onClicked: if (root.hasPlayer) root.sh("playerctl " + (modelData === "play" ? "play-pause" : modelData === "next" ? "next" : "previous") + "; true")
                    }
                }
            }
        }
    }

    // ---- power buttons ----
    Row {
        anchors { right: parent.right; rightMargin: 40 * root.k; bottom: parent.bottom; bottomMargin: 40 * root.k }
        spacing: 26 * root.k
        Repeater {
            model: [
                { id: "sleep", label: "Sleep", cmd: "systemctl suspend" },
                { id: "restart", label: "Restart", cmd: "systemctl reboot" },
                { id: "off", label: "Shut down", cmd: "systemctl poweroff" }
            ]
            Column {
                spacing: 6 * root.k
                Rectangle {
                    id: pb
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 58 * root.k; height: width; radius: width / 2
                    color: pma.pressed ? root.rust : (pma.containsMouse ? root.mid : (root.dusk ? "#2effffff" : "#ddf6f1e4"))
                    border.color: root.dusk ? "#55cfe3d4" : "#8a9a90"; border.width: 1
                    scale: pma.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Canvas {
                        anchors.fill: parent
                        property bool hot: pma.containsMouse || pma.pressed
                        onHotChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset()
                            var w = width, h = height, cx = w / 2, cy = h / 2, r = w * 0.2
                            c.strokeStyle = hot ? root.cream : root.ink; c.fillStyle = c.strokeStyle
                            c.lineWidth = Math.max(2, w * 0.06); c.lineCap = "round"
                            if (modelData.id === "sleep") {   // crescent moon
                                c.beginPath(); c.arc(cx, cy, r * 1.05, 0.5 * Math.PI, 1.9 * Math.PI, false)
                                c.arc(cx + r * 0.45, cy - r * 0.25, r * 0.85, 1.75 * Math.PI, 0.6 * Math.PI, true)
                                c.closePath(); c.fill()
                            } else if (modelData.id === "restart") {   // circular arrow
                                c.beginPath(); c.arc(cx, cy, r, -0.35 * Math.PI, 1.55 * Math.PI, false); c.stroke()
                                c.beginPath(); c.moveTo(cx + r * 1.05, cy - r * 1.25); c.lineTo(cx + r * 1.05, cy - r * 0.35); c.lineTo(cx + r * 0.2, cy - r * 0.6); c.closePath(); c.fill()
                            } else {   // power symbol
                                c.beginPath(); c.arc(cx, cy + r * 0.1, r, -0.3 * Math.PI, 1.3 * Math.PI, false); c.stroke()
                                c.beginPath(); c.moveTo(cx, cy - r * 1.1); c.lineTo(cx, cy - r * 0.1); c.stroke()
                            }
                        }
                    }
                    MouseArea {
                        id: pma; anchors.fill: parent; hoverEnabled: true
                        onClicked: root.sh(modelData.cmd + "; true")
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label; color: root.ink
                    font.pixelSize: 14 * root.k; font.family: "Noto Sans"
                }
            }
        }
    }

    Component.onCompleted: { authenticator.startAuthenticating(); pw.forceActiveFocus(); console.log("ELTOLOCK greeter qml loaded") }
}
