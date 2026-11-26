// ElTo Customize (CONCEPT until approved): standalone window, run with `quickshell -p customize.qml`.
// Appearance page: theme, wallpaper, lock/login previews, dock, notch, soft motion. Changes write ~/.config/elto/theme.json,
// which the shell watches, so they apply instantly. All look values come from Theme.
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: app

    // ---- write a changed option into the user overlay (deep copy of what is already there)
    Process { id: writer }
    function setOption(key, value) {
        var u = JSON.parse(JSON.stringify(Theme.user))
        if (!u.options) u.options = {}
        u.options[key] = value
        var dir = Theme.userPath.substring(0, Theme.userPath.lastIndexOf("/"))
        writer.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", dir, JSON.stringify(u, null, 2), Theme.userPath]
        writer.running = true
        console.log("ELTOCUSTOMIZE set " + key + "=" + value)
    }

    readonly property var themes: [
        { id: "soft-paper", label: "Soft paper", real: true, sw: ["cream", "lightGreen", "midGreen", "green", "rust"] },
        { id: "night-paper", label: "Night paper", real: false, sw: ["#1d2a24", "#2d4038", "#4c7860", "#d8cfb4", "#a05040"] },
        { id: "moss", label: "Moss", real: false, sw: ["#e6efe0", "#a5c8aa", "#4c7860", "#1c3a2a", "#cf8a3c"] }
    ]
    readonly property var walls: [
        { f: "dusk-hills.png", l: "Dusk hills" },
        { f: "aquarelle-paper.png", l: "Aquarelle paper" },
        { f: "misty-dawn.png", l: "Misty dawn" },
        { f: "golden-valley.png", l: "Golden valley" },
        { f: "moonlit-swirl.png", l: "Moonlit swirl" },
        { f: "snail-stem-mist.png", l: "Snail stem mist" },
        { f: "snail-rock-water.png", l: "Snail rock water" },
        { f: "cezanne-mont-sainte-victoire.jpg", l: "Mont Sainte-Victoire" },
        { f: "kensett-hudson-river-scene.jpg", l: "Hudson River scene" },
        { f: "cropsey-valley-of-wyoming.jpg", l: "Valley of Wyoming" }
    ]
    function wallLabel(f) { for (var i = 0; i < walls.length; i++) if (walls[i].f === f) return walls[i].l; return f }
    function swatch(c) { return c.charAt(0) === "#" ? c : Theme.color(c) }

    FloatingWindow {
        id: win
        title: "Customize"
        implicitWidth: 1180; implicitHeight: 690
        minimumSize: Qt.size(1180, 690); maximumSize: Qt.size(1180, 690)
        color: "transparent"

        Rectangle {
            anchors.fill: parent; radius: Theme.radiusWindow; color: Theme.surface; clip: true
            border.width: 1; border.color: Theme.divider

            // ---------- sidebar
            Rectangle {
                id: side
                width: 172; height: parent.height; color: Theme.surfaceAlt
                Column {
                    x: 12; y: 76; spacing: 4; width: parent.width - 24
                    Repeater {
                        model: [{ i: "palette", t: "Appearance", on: true }]
                        Rectangle {
                            required property var modelData
                            width: parent.width; height: 38; radius: 19
                            color: modelData.on ? Theme.selection : "transparent"
                            Row {
                                x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                LIcon { name: modelData.i; size: 18; tint: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.t; color: Theme.text; font.family: Theme.sans; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }

            // ---------- header
            Text { x: side.width + 28; y: 22; text: "Appearance"; color: Theme.text; font.family: Theme.serif; font.pixelSize: 38; renderType: Text.NativeRendering }
            Text { anchors.right: parent.right; anchors.rightMargin: 30; y: 40; text: "Changes apply instantly"
                color: Theme.textMuted; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 16; renderType: Text.NativeRendering }

            // ---------- left column
            Item {
                id: leftCol
                x: side.width + 28; y: 84; width: 460; height: parent.height - 100

                Text { text: "Theme"; color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22; renderType: Text.NativeRendering }
                Row {
                    y: 34; spacing: 10
                    Repeater {
                        model: app.themes
                        Rectangle {
                            id: tc
                            required property var modelData
                            readonly property bool cur: modelData.real && Theme.name === modelData.id
                            width: 146; height: 92; radius: Theme.radiusCard
                            color: Theme.surfaceAlt
                            border.width: cur ? 2 : 0; border.color: Theme.accent
                            opacity: modelData.real ? 1 : 0.6
                            Row { x: 14; y: 14; spacing: 6
                                Repeater { model: tc.modelData.sw
                                    Rectangle { required property string modelData; width: 20; height: 20; radius: 10; color: app.swatch(modelData)
                                        border.width: 1; border.color: Theme.divider } } }
                            Text { x: 14; y: 56; text: tc.modelData.label; color: Theme.text; font.family: Theme.sans; font.pixelSize: 15 }
                            Rectangle { visible: tc.cur; x: parent.width - 34; y: parent.height - 34; width: 24; height: 24; radius: 12; color: Theme.accent
                                Text { anchors.centerIn: parent; text: "\u2713"; color: Theme.surface; font.pixelSize: 15; font.bold: true } }
                            Text { visible: !tc.modelData.real; x: 92; y: 58; text: "concept"; color: Theme.disabled; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 12 }
                        }
                    }
                }

                Text { y: 150; text: "Desktop wallpaper"; color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22; renderType: Text.NativeRendering }
                Flickable {
                    y: 186; width: parent.width + 10; height: leftCol.height - 190
                    contentHeight: grid.height; clip: true
                    Grid {
                        id: grid; columns: 3; spacing: 12
                        Repeater {
                            model: app.walls
                            Item {
                                id: wc
                                required property var modelData
                                readonly property bool cur: Theme.wallpaper === modelData.f
                                width: 144; height: 124
                                Rectangle {
                                    id: frame
                                    width: parent.width; height: 92; radius: 12; color: Theme.surfaceAlt; clip: true
                                    Image { anchors.fill: parent; source: "file://" + Quickshell.shellPath("../wallpapers/" + wc.modelData.f)
                                        fillMode: Image.PreserveAspectCrop; sourceSize.width: 320; sourceSize.height: 200; asynchronous: true }
                                    Rectangle { anchors.fill: parent; radius: 12; color: "transparent"; border.width: wc.cur ? 2.5 : 0; border.color: Theme.accent }
                                    Rectangle { visible: wc.cur; x: parent.width - 28; y: 6; width: 22; height: 22; radius: 11; color: Theme.accent
                                        Text { anchors.centerIn: parent; text: "\u2713"; color: Theme.surface; font.pixelSize: 14; font.bold: true } }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.setOption("wallpaper", wc.modelData.f) }
                                }
                                Text { y: 96; width: parent.width; elide: Text.ElideRight; text: wc.modelData.l; color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 13 }
                            }
                        }
                    }
                }
            }

            // ---------- right column
            Item {
                id: rightCol
                x: side.width + 28 + 490; y: 84; width: parent.width - x - 30; height: parent.height - 100

                Text { text: "Lock screen and login"; color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22; renderType: Text.NativeRendering }
                Row {
                    y: 34; spacing: 12
                    Repeater {
                        model: [{ k: "lock", l: "Lock screen", c: "Same as desktop" }, { k: "login", l: "Login", c: "Same as desktop" }]
                        Column {
                            id: pv
                            required property var modelData
                            spacing: 6
                            Rectangle {
                                width: (rightCol.width - 12) / 2; height: 108; radius: 12; clip: true; color: Theme.surfaceAlt
                                Image { anchors.fill: parent; source: "file://" + Quickshell.shellPath("../wallpapers/" + Theme.wallpaper)
                                    fillMode: Image.PreserveAspectCrop; sourceSize.width: 320; sourceSize.height: 200; asynchronous: true }
                                Text { visible: pv.modelData.k === "lock"; anchors.horizontalCenter: parent.horizontalCenter; y: 12; text: "10:42"
                                    color: Theme.text; font.family: Theme.serif; font.pixelSize: 26 }
                                Image { visible: pv.modelData.k === "login"; width: 34; height: 34; anchors.horizontalCenter: parent.horizontalCenter; y: 10
                                    source: "file://" + Quickshell.shellPath("../lock/assets/snail.png"); fillMode: Image.PreserveAspectFit }
                                Rectangle { visible: pv.modelData.k === "login"; width: 90; height: 18; radius: 9; color: Theme.surface; anchors.horizontalCenter: parent.horizontalCenter; y: 72
                                    Text { anchors.centerIn: parent; text: "Password"; color: Theme.disabled; font.family: Theme.sans; font.pixelSize: 9 } }
                            }
                            Text { text: pv.modelData.l; color: Theme.text; font.family: Theme.sans; font.pixelSize: 14 }
                            Rectangle { width: (rightCol.width - 12) / 2; height: 30; radius: 15; color: Theme.surfaceAlt
                                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: pv.modelData.c; color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 12 } }
                        }
                    }
                }

                Text { y: 232; text: "Dock"; color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22; renderType: Text.NativeRendering }
                Row {
                    y: 266; spacing: 10
                    Repeater {
                        model: [{ id: "island", l: "Island", real: true }, { id: "ridge-shelf", l: "Ridge shelf", real: false }, { id: "hidden-thread", l: "Hidden thread", real: false }]
                        Rectangle {
                            id: dc
                            required property var modelData
                            readonly property bool cur: Theme.dockStyle === modelData.id
                            width: (rightCol.width - 20) / 3; height: 96; radius: Theme.radiusCard; color: Theme.surfaceAlt
                            border.width: cur ? 2 : 0; border.color: Theme.accent
                            opacity: modelData.real ? 1 : 0.6
                            Rectangle { x: 12; y: 10; width: parent.width - 24; height: 46; radius: 8; color: Theme.selection }
                            Rectangle { visible: dc.modelData.id === "island"; width: 40; height: 10; radius: 5; color: Theme.surface; anchors.horizontalCenter: parent.horizontalCenter; y: 36 }
                            Rectangle { visible: dc.modelData.id === "hidden-thread"; x: 12; y: 54; width: parent.width - 24; height: 2; color: Theme.textMuted }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 66; text: dc.modelData.l; color: Theme.text; font.family: Theme.sans; font.pixelSize: 13 }
                            Text { visible: !dc.modelData.real; anchors.horizontalCenter: parent.horizontalCenter; y: 82; text: "concept"; color: Theme.disabled; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; enabled: dc.modelData.real; onClicked: app.setOption("dock", dc.modelData.id) }
                        }
                    }
                }

                Rectangle { y: 380; width: parent.width; height: 54; radius: Theme.radiusCard; color: Theme.surfaceAlt
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "Notch style"; color: Theme.text; font.family: Theme.sans; font.pixelSize: 15 }
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: 100; height: 32; radius: 16; color: Theme.surface
                        Text { anchors.centerIn: parent; text: Theme.optionsT.notch === "clock" ? "Clock" : Theme.optionsT.notch; color: Theme.text; font.family: Theme.sans; font.pixelSize: 13 } } }

                Rectangle { y: 444; width: parent.width; height: 54; radius: Theme.radiusCard; color: Theme.surfaceAlt
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "Soft motion"; color: Theme.text; font.family: Theme.sans; font.pixelSize: 15 }
                    Rectangle {
                        id: tog
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 54; height: 30; radius: 15; color: Theme.motion ? Theme.color("midGreen") : Theme.divider
                        Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
                        Rectangle { y: 3; x: Theme.motion ? parent.width - width - 3 : 3; width: 24; height: 24; radius: 12; color: Theme.surface
                            Behavior on x { NumberAnimation { duration: Theme.ms(150); easing.type: Easing.OutCubic } } }
                        MouseArea { anchors.fill: parent; onClicked: app.setOption("motion", Theme.motion ? "off" : "soft") }
                    }
                }
            }
        }
    }
}
