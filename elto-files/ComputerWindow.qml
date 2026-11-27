// "This computer" page: folder shortcuts and drive cards with usage bars and Eject.
import Quickshell
import QtQuick

FloatingWindow {
    id: win
    required property var app
    readonly property var th: app.theme
    title: "This computer"
    implicitWidth: 700; implicitHeight: 490
    minimumSize: Qt.size(660, 470)
    color: "transparent"
    visible: app.computerVisible
    onVisibleChanged: { app.computerVisible = visible; if (visible) app.refreshDrives() }

    readonly property var folders: ["Documents", "Downloads", "Pictures", "Music", "Videos"]
    readonly property var words: ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
    function word(n) { return n < words.length ? words[n] : String(n) }
    function gb(b) { var v = b / 1e9; return (v >= 10 ? Math.round(v) : Math.round(v * 10) / 10) + " GB" }
    function pct(d) { return d.total > 0 ? Math.round(d.used * 100 / d.total) : 0 }

    Rectangle {
        anchors.fill: parent
        radius: th.radiusWindow; color: th.surface; clip: true
        border.width: 1; border.color: th.divider

        Item {
            anchors { fill: parent; leftMargin: 32; rightMargin: 32; topMargin: 22; bottomMargin: 22 }

            Text {
                id: title
                text: "This computer"; color: th.text
                font.family: th.serif; font.pixelSize: 44; renderType: Text.NativeRendering
            }
            Text {
                anchors { right: parent.right; bottom: title.bottom; bottomMargin: 14 }
                text: win.word(app.drives.length) + " drive" + (app.drives.length === 1 ? "" : "s") + ", " + win.word(win.folders.length) + " folders"
                color: th.textMuted; font.family: th.serif; font.italic: true; font.pixelSize: 13
            }
            // hand-drawn rule with a snail at the end
            Canvas {
                id: rule
                anchors { top: title.bottom; topMargin: 0; left: parent.left; right: parent.right; rightMargin: 34 }
                height: 8
                onWidthChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"); c.reset()
                    c.strokeStyle = th.text.toString(); c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round"
                    c.beginPath(); c.moveTo(1, 4)
                    for (var x = 8; x < width; x += 8) c.lineTo(x, 4 + Math.sin(x * 0.07) * 1.2 + Math.sin(x * 0.31) * 0.6)
                    c.stroke()
                }
            }
            Image {
                anchors { left: rule.right; leftMargin: 2; verticalCenter: rule.verticalCenter; verticalCenterOffset: -8 }
                width: 28; height: 21; source: app.icon("snail"); sourceSize.width: 56; sourceSize.height: 42
            }

            Text { id: fHead; y: 82; text: "Folders"; color: th.text; font.family: th.serif; font.italic: true; font.pixelSize: 18 }
            Rectangle { y: 92; x: 74; width: parent.width - 74; height: 1; color: th.divider }
            Row {
                id: fRow
                y: 116; width: parent.width
                Repeater {
                    model: win.folders
                    Item {
                        required property string modelData
                        readonly property string p: app.home + "/" + modelData
                        width: fRow.width / win.folders.length; height: 104
                        Image {
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                            width: 64; height: 56; source: app.icon("folder")
                            sourceSize.width: 128; sourceSize.height: 112
                        }
                        Text {
                            anchors { top: parent.top; topMargin: 62; horizontalCenter: parent.horizontalCenter }
                            text: modelData; color: th.text; font.family: th.sans; font.pixelSize: 12; font.weight: Font.Medium
                        }
                        Text {
                            anchors { top: parent.top; topMargin: 80; horizontalCenter: parent.horizontalCenter }
                            property int n: app.counts[p] !== undefined ? app.counts[p] : 0
                            text: n + (n === 1 ? " item" : " items"); color: th.textMuted
                            font.family: th.serif; font.italic: true; font.pixelSize: 10
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(p) }
                    }
                }
            }

            Text { id: dHead; y: 236; text: "Drives"; color: th.text; font.family: th.serif; font.italic: true; font.pixelSize: 18 }
            Rectangle { y: 246; x: 60; width: parent.width - 60; height: 1; color: th.divider }
            Flickable {
                y: 266; width: parent.width; height: 160
                contentWidth: dRow.width; contentHeight: height; clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: dRow
                    spacing: 14
                    Repeater {
                        model: app.drives
                        Rectangle {
                            id: card
                            required property var modelData
                            readonly property int pc: win.pct(modelData)
                            readonly property color tone: pc >= 85 ? th.accent : th.textMuted
                            width: 192; height: 156; radius: 16
                            color: Qt.lighter(th.surface, 1.35)
                            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.05)
                            Canvas {          // dashed inner outline
                                anchors.fill: parent; anchors.margins: 6
                                onPaint: {
                                    var c = getContext("2d"); c.reset()
                                    c.strokeStyle = th.divider.toString(); c.lineWidth = 1; c.setLineDash([4, 4])
                                    c.strokeRect(0.5, 0.5, width - 1, height - 1)
                                }
                            }
                            Image {
                                x: 16; y: 16; width: 52; height: card.modelData.removable ? 26 : 32
                                fillMode: Image.PreserveAspectFit; horizontalAlignment: Image.AlignLeft
                                source: app.icon(card.modelData.removable ? "drive-usb" : "drive-internal")
                                sourceSize.width: 128; sourceSize.height: 80
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 10 }
                                text: card.pc + "%"; color: card.pc >= 85 ? th.accent : th.text
                                font.family: th.serif; font.pixelSize: 34
                            }
                            Text {
                                x: 16; y: 56; width: parent.width - 100; elide: Text.ElideRight
                                text: card.modelData.name; color: th.text; font.family: th.serif; font.pixelSize: 24
                            }
                            Text {
                                x: 16; y: 88; width: parent.width - 32; elide: Text.ElideRight
                                text: card.modelData.kind; color: th.textMuted; font.family: th.serif; font.italic: true; font.pixelSize: 9
                            }
                            Rectangle {   // Eject (removable drives only)
                                visible: card.modelData.removable && card.modelData.dev !== ""
                                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 66 }
                                width: 64; height: 22; radius: 11; color: th.surface
                                border.width: 1; border.color: th.divider
                                Row {
                                    anchors.centerIn: parent; spacing: 4
                                    Image { width: 8; height: 8; anchors.verticalCenter: parent.verticalCenter; source: app.icon("close"); sourceSize.width: 16; sourceSize.height: 16 }
                                    Text { text: "Eject"; color: th.text; font.family: th.sans; font.pixelSize: 10; font.weight: Font.Medium }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(card.modelData.dev) }
                            }
                            Rectangle {   // usage bar
                                x: 16; y: 104; width: parent.width - 32; height: 10; radius: 5; color: th.surfaceAlt
                                Rectangle {
                                    width: Math.max(10, parent.width * card.pc / 100); height: parent.height; radius: 5
                                    color: card.tone; clip: true
                                    Canvas {
                                        anchors.fill: parent
                                        onPaint: {
                                            var c = getContext("2d"); c.reset()
                                            c.strokeStyle = "rgba(255,255,255,0.28)"; c.lineWidth = 2
                                            for (var x = -height; x < width; x += 6) { c.beginPath(); c.moveTo(x, height); c.lineTo(x + height, 0); c.stroke() }
                                        }
                                    }
                                }
                            }
                            Text {
                                x: 16; y: 124
                                text: win.gb(card.modelData.used) + " of " + win.gb(card.modelData.total) + " used"
                                color: th.text; font.family: th.sans; font.pixelSize: 9; font.weight: Font.Medium
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 16 }
                                y: 123
                                text: win.gb(card.modelData.free) + " free"
                                color: th.textMuted; font.family: th.serif; font.italic: true; font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor
                                onClicked: app.openPath(card.modelData.mount)
                            }
                        }
                    }
                }
            }
        }
    }
}
