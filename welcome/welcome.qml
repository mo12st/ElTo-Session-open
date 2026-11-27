// ElTo Welcome (Phase 2, approved design): first-run tour as a standalone Quickshell window.
// Run: quickshell -p welcome/welcome.qml
// Autostarted once per major version by welcome/elto-welcome-autostart.sh (checks the marker);
// re-openable anytime from the app drawer via welcome/elto-welcome.desktop.
// Writes ${XDG_STATE_HOME:-~/.local/state}/elto/welcome-v1.done when finished or skipped.
//
// Styling reads the same theme files as the shell (themes/soft-paper/theme.json + the user
// overlay ~/.config/elto/theme.json) and merges them the same way. It is inlined here on
// purpose: panel-widgets/Theme.qml is a QML singleton local to its directory and cannot be
// imported across directories without a qmldir file (which belongs to the implementer's track).
// LIcon.qml is a local copy (the panel-widgets one needs the Theme singleton, which does not resolve across directories).
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: app

    // Bump when a new major version should re-show Welcome ("what's new").
    readonly property int welcomeVersion: 1
    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property string markerPath: stateDir + "/elto/welcome-v" + welcomeVersion + ".done"

    // ---- theme: same merge as panel-widgets/Theme.qml (soft-paper base + user overlay), read-only ----
    QtObject {
        id: th
        property var base: ({})
        property var user: ({})
        function section(name) {
            var out = {}, b = base[name] || {}, u = user[name] || {}
            for (var k in b) out[k] = b[k]
            for (var j in u) out[j] = u[j]
            return out
        }
        readonly property var colors: section("colors")
        readonly property var roles: section("roles")
        readonly property var shapeT: section("shape")
        readonly property var fonts: section("fonts")
        readonly property var options: section("options")
        function role(r) { var n = roles[r]; return colors[n] !== undefined ? colors[n] : (colors[r] !== undefined ? colors[r] : "#f6f1e4") }
        readonly property color surface: role("surface")
        readonly property color surfaceAlt: role("surfaceAlt")
        readonly property color text: role("text")
        readonly property color textMuted: role("textMuted")
        readonly property color accent: role("accent")
        readonly property color selection: role("selection")
        readonly property color divider: role("divider")
        readonly property int radiusWindow: shapeT.radiusWindow !== undefined ? shapeT.radiusWindow : 22
        readonly property int radiusCard: shapeT.radiusCard !== undefined ? shapeT.radiusCard : 14
        readonly property string serif: fonts.serif || "Noto Serif Display"
        readonly property string serifItalic: fonts.serifItalic || "Noto Serif Display Italic"
        readonly property string sans: fonts.sans || "Noto Sans"
        readonly property bool motion: options.motion !== "off"
        function ms(v) { return motion ? v : 0 }
    }
    FileView {
        path: Quickshell.shellPath("../themes/soft-paper/theme.json")
        blockLoading: true
        onLoaded: { try { th.base = JSON.parse(text()) } catch (e) { console.log("ELTOWELCOME base parse error " + e) } }
    }
    FileView {
        path: Quickshell.env("ELTO_THEME") || (Quickshell.env("HOME") + "/.config/elto/theme.json")
        blockLoading: true
        onLoaded: { try { th.user = JSON.parse(text()) } catch (e) { console.log("ELTOWELCOME user parse error " + e) } }
        onLoadFailed: th.user = ({})
    }

    // ---- marker write, then quit (same sh -c pattern as panel-widgets/UserTheme.qml) ----
    Process { id: markerProc; onExited: Qt.quit() }
    Process { id: openProc }
    Timer { id: quitGuard; interval: 4000; onTriggered: Qt.quit() } // never trap the user if the write hangs

    function finish() {
        markerProc.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s\n' \"$2\" > \"$3\"", "sh",
            app.stateDir + "/elto",
            JSON.stringify({ welcomeVersion: app.welcomeVersion, shownAt: new Date().toISOString() }),
            app.markerPath]
        markerProc.running = true
        quitGuard.running = true
    }

    function openCustomize() {
        if (openProc.running) return
        openProc.command = ["quickshell", "-p", Quickshell.shellPath("../panel-widgets/customize.qml")]
        openProc.running = true
    }

    FloatingWindow {
        id: win
        title: "Welcome to ElTo"
        implicitWidth: 920; implicitHeight: 620
        minimumSize: Qt.size(920, 620); maximumSize: Qt.size(920, 620)
        color: "transparent"

        Rectangle {
            id: card
            anchors.fill: parent; radius: th.radiusWindow; color: th.surface; clip: true
            border.width: 1; border.color: th.divider
            focus: true
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right && pager.page < 3) { pager.page += 1; event.accepted = true }
                else if (event.key === Qt.Key_Left && pager.page > 0) { pager.page -= 1; event.accepted = true }
                else if (event.key === Qt.Key_Escape) { app.finish(); event.accepted = true }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (pager.page < 3) pager.page += 1; else app.finish()
                    event.accepted = true
                }
            }

            QtObject { id: pager; property int page: 0 }

            // ================= page 0: welcome =================
            Item {
                anchors.fill: parent; visible: pager.page === 0
                Image {
                    x: 0; y: 0; width: parent.width; height: 300
                    source: "file://" + Quickshell.shellPath("../wallpapers/golden-valley.png")
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                    sourceSize.width: 1840; sourceSize.height: 600
                }
                Rectangle { // fade the banner into the paper surface
                    x: 0; y: 200; width: parent.width; height: 100
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00" + th.surface.toString().slice(1) }
                        GradientStop { position: 1.0; color: th.surface }
                    }
                }
                Image {
                    x: 56; y: 216; width: 96; height: 96
                    source: "file://" + Quickshell.shellPath("../lock/assets/snail.png")
                    fillMode: Image.PreserveAspectFit; asynchronous: true
                }
                Text {
                    x: 172; y: 236; width: parent.width - 220
                    text: "Welcome to ElTo"
                    color: th.text; font.family: th.serif; font.pixelSize: 44
                }
                Text {
                    x: 60; y: 340; width: parent.width - 120
                    wrapMode: Text.WordWrap
                    text: "ElTo is a desktop shaped like a small world of its own: calm paper, soft color, and a shell built around a few quiet ideas. This short tour shows you the essentials. It takes less than a minute."
                    color: th.textMuted; font.family: th.sans; font.pixelSize: 17; lineHeight: 1.35
                }
            }

            // ================= page 1: the tour =================
            Item {
                anchors.fill: parent; visible: pager.page === 1
                Text {
                    x: 60; y: 44; text: "Three things to know"
                    color: th.text; font.family: th.serif; font.pixelSize: 34
                }
                Column {
                    x: 60; y: 116; width: parent.width - 120; spacing: 18

                    // the notch
                    Rectangle {
                        width: parent.width; height: 130; radius: th.radiusCard; color: th.surfaceAlt
                        Rectangle { // mini diagram: the notch pill
                            x: 34; y: 40; width: 120; height: 50; radius: 25; color: th.surface
                            border.width: 1; border.color: th.divider
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Repeater {
                                    model: 3
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: th.textMuted }
                                }
                            }
                        }
                        Text { x: 190; y: 22; text: "The notch"; color: th.text; font.family: th.serif; font.pixelSize: 21 }
                        Text {
                            x: 190; y: 54; width: parent.width - 230; wrapMode: Text.WordWrap
                            text: "At the top center, holding your clock and music. Pull it down for quick controls like volume and network."
                            color: th.textMuted; font.family: th.sans; font.pixelSize: 15; lineHeight: 1.3
                        }
                    }

                    // the dock
                    Rectangle {
                        width: parent.width; height: 130; radius: th.radiusCard; color: th.surfaceAlt
                        Rectangle { // mini diagram: dock island with tiles and a pill
                            x: 14; y: 40; width: 160; height: 50; radius: 25; color: th.surface
                            border.width: 1; border.color: th.divider
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                Repeater {
                                    model: 3
                                    Rectangle { width: 22; height: 22; radius: 11; color: th.selection }
                                }
                                Rectangle { width: 44; height: 22; radius: 11; color: th.accent }
                            }
                        }
                        Text { x: 190; y: 22; text: "The dock"; color: th.text; font.family: th.serif; font.pixelSize: 21 }
                        Text {
                            x: 190; y: 54; width: parent.width - 230; wrapMode: Text.WordWrap
                            text: "The island at the bottom keeps your pinned apps. Every open window appears as a pill you can jump to."
                            color: th.textMuted; font.family: th.sans; font.pixelSize: 15; lineHeight: 1.3
                        }
                    }

                    // the drawer
                    Rectangle {
                        width: parent.width; height: 130; radius: th.radiusCard; color: th.surfaceAlt
                        Grid { // mini diagram: app grid
                            x: 44; y: 30; columns: 4; spacing: 8
                            Repeater {
                                model: 8
                                Rectangle { width: 16; height: 16; radius: 8; color: th.selection }
                            }
                        }
                        Text { x: 190; y: 22; text: "The drawer"; color: th.text; font.family: th.serif; font.pixelSize: 21 }
                        Text {
                            x: 190; y: 54; width: parent.width - 230; wrapMode: Text.WordWrap
                            text: "Tap the snail in the notch to open the drawer: every installed app in one calm grid, with search."
                            color: th.textMuted; font.family: th.sans; font.pixelSize: 15; lineHeight: 1.3
                        }
                    }
                }
            }

            // ================= page 2: make it yours =================
            Item {
                anchors.fill: parent; visible: pager.page === 2
                LIcon { x: 60; y: 56; name: "palette"; size: 44; tint: th.accent }
                Text {
                    x: 128; y: 58; text: "Make it yours"
                    color: th.text; font.family: th.serif; font.pixelSize: 34
                }
                Text {
                    x: 60; y: 140; width: parent.width - 120; wrapMode: Text.WordWrap
                    text: "Wallpapers, themes, the dock, motion: Customize is where ElTo takes your shape. Changes apply the moment you make them, and Customize is always one tap away in the dock."
                    color: th.textMuted; font.family: th.sans; font.pixelSize: 17; lineHeight: 1.35
                }
                Rectangle {
                    x: 60; y: 250; width: 220; height: 52; radius: 26
                    color: openArea.containsMouse ? th.selection : th.surfaceAlt
                    border.width: 1; border.color: th.divider
                    Behavior on color { ColorAnimation { duration: th.ms(120) } }
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        LIcon { name: "palette"; size: 20; tint: th.text }
                        Text { text: "Open Customize"; color: th.text; font.family: th.sans; font.pixelSize: 16 }
                    }
                    MouseArea {
                        id: openArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: app.openCustomize()
                    }
                }
                Text {
                    x: 60; y: 330; width: parent.width - 120; wrapMode: Text.WordWrap
                    text: "Nothing here is permanent. Try things; ElTo forgives."
                    color: th.textMuted; font.family: th.serifItalic; font.pixelSize: 16
                }
            }

            // ================= page 3: done =================
            Item {
                anchors.fill: parent; visible: pager.page === 3
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 90
                    width: 110; height: 110
                    source: "file://" + Quickshell.shellPath("../lock/assets/snail.png")
                    fillMode: Image.PreserveAspectFit; asynchronous: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 220
                    text: "That's everything you need to begin."
                    color: th.text; font.family: th.serif; font.pixelSize: 28
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 278
                    text: "Take your time. ElTo keeps things slow on purpose."
                    color: th.textMuted; font.family: th.serifItalic; font.pixelSize: 17
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 350
                    width: 240; height: 56; radius: 28
                    color: startArea.containsMouse ? th.color("lightGreen") : th.selection
                    border.width: 1; border.color: th.divider
                    Behavior on color { ColorAnimation { duration: th.ms(120) } }
                    Text {
                        anchors.centerIn: parent
                        text: "Start using ElTo"; color: th.text; font.family: th.sans; font.pixelSize: 17
                    }
                    MouseArea {
                        id: startArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: app.finish()
                    }
                }
            }

            // ================= footer: dots, back/next, skip =================
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 66; spacing: 10
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 9; height: 9; radius: 4.5
                        color: pager.page === index ? th.accent : th.divider
                        Behavior on color { ColorAnimation { duration: th.ms(120) } }
                    }
                }
            }
            Text {
                x: 40; y: parent.height - 76
                text: "Skip the tour"
                color: skipArea.containsMouse ? th.text : th.textMuted
                font.family: th.sans; font.pixelSize: 14; font.underline: skipArea.containsMouse
                visible: pager.page < 3
                MouseArea {
                    id: skipArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: app.finish()
                }
            }
            Rectangle {
                id: nextBtn
                anchors.right: parent.right; anchors.rightMargin: 40; y: parent.height - 88
                width: 128; height: 46; radius: 23
                visible: pager.page < 3
                color: nextArea.containsMouse ? th.selection : th.surfaceAlt
                border.width: 1; border.color: th.divider
                Behavior on color { ColorAnimation { duration: th.ms(120) } }
                Text { anchors.centerIn: parent; text: "Next"; color: th.text; font.family: th.sans; font.pixelSize: 15 }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: pager.page += 1
                }
            }
            Text {
                anchors.right: nextBtn.left; anchors.rightMargin: 18; y: parent.height - 76
                visible: pager.page > 0
                text: "Back"
                color: backArea.containsMouse ? th.text : th.textMuted
                font.family: th.sans; font.pixelSize: 14; font.underline: backArea.containsMouse
                MouseArea {
                    id: backArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: pager.page -= 1
                }
            }
        }
    }
}
