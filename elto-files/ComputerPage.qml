// "This computer" page, shown inside the Trail window: folder shortcuts and drive cards with usage bars and Eject.
import QtQuick

Item {
    id: page
    required property var app
    readonly property var th: app.theme
    onVisibleChanged: if (visible) app.refreshDrives()

    readonly property real cardScale: 0.84
    // Era of the page look, derived from the world's folderArt token. Layout is the same in every era.
    readonly property string era: {
        var f = th.folderArt
        if (f === "classic95") return "w95"
        if (f === "aero" || f === "luna" || f === "chrome") return f
        if (f === "outline") return th.iconArt === "ascii" ? "term" : "plain"
        return "paper"
    }
    readonly property bool paper: era === "paper"
    readonly property string hf: paper ? th.serif : (era === "term" ? th.mono : th.sans)
    readonly property bool boldHead: era === "w95" || era === "luna"
    readonly property color accentText: th.lum(th.accent) < 0.5 ? th.surface : th.text
    onEraChanged: { rule.requestPaint() }
    readonly property var folders: ["Documents", "Downloads", "Pictures", "Music", "Videos"]
    readonly property var words: ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
    function word(n) { return n < words.length ? words[n] : String(n) }
    function gb(b) { var v = b / 1e9; return (v >= 10 ? Math.round(v) : Math.round(v * 10) / 10) + " GB" }
    function pct(d) { return d.total > 0 ? Math.round(d.used * 100 / d.total) : 0 }

    component Head: Item {
        property string label
        property real ruleX
        width: parent.width; height: 22
        readonly property bool bar: page.era === "luna"
        Rectangle {
            visible: parent.bar; anchors.fill: parent; radius: 6; height: 22
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(th.accent, 1.25) }
                GradientStop { position: 1; color: th.accent }
            }
        }
        Text {
            id: ht
            x: parent.bar ? 10 : 0; anchors.verticalCenter: parent.verticalCenter
            text: (page.era === "term" ? "## " : "") + parent.label
            color: parent.bar ? page.accentText : th.text
            font.family: page.hf; font.italic: page.paper; font.bold: page.boldHead; font.pixelSize: 18
            font.capitalization: page.era === "chrome" ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: page.era === "chrome" ? 2 : 0
        }
        Rectangle {
            visible: !parent.bar; x: Math.max(parent.ruleX, ht.width + 12); y: 10; width: parent.width - x
            height: page.era === "chrome" ? 2 : 1
            color: page.era === "chrome" || page.era === "aero" ? th.accent : th.divider
            opacity: page.era === "aero" ? 0.6 : 1
        }
    }

    Item {
        anchors.fill: parent

            Text {
                id: title
                text: "This computer"; color: th.text
                font.family: page.hf; font.pixelSize: page.era === "w95" || page.era === "term" ? 38 : 44; font.bold: page.boldHead
                font.capitalization: page.era === "chrome" ? Font.AllUppercase : Font.MixedCase; font.letterSpacing: page.era === "chrome" ? 2 : 0; renderType: Text.NativeRendering
            }
            Text {
                anchors { right: parent.right; bottom: title.bottom; bottomMargin: 14 }
                text: page.word(app.drives.length) + " drive" + (app.drives.length === 1 ? "" : "s") + ", " + page.word(page.folders.length) + " folders"
                color: th.textMuted; font.family: page.hf; font.italic: page.paper; font.pixelSize: 13
            }
            // hand-drawn rule with a snail at the end
            Canvas {
                id: rule
                anchors { top: title.bottom; topMargin: 0; left: parent.left; right: parent.right; rightMargin: 34 }
                height: 8
                onWidthChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"); c.reset()
                    var e = page.era, w = width, ac = th.accent.toString(), tx = th.text.toString()
                    if (e === "w95") {
                        c.fillStyle = Qt.darker(th.surface, 1.8).toString(); c.fillRect(0, 2, w, 2)
                        c.fillStyle = Qt.lighter(th.surface, 1.8).toString(); c.fillRect(0, 4, w, 2)
                    } else if (e === "aero" || e === "luna") {
                        var g = c.createLinearGradient(0, 0, w, 0)
                        g.addColorStop(0, ac); g.addColorStop(1, Qt.alpha(th.accent, 0).toString())
                        c.fillStyle = g; c.fillRect(0, 2, w, e === "luna" ? 4 : 2)
                    } else if (e === "chrome") {
                        c.fillStyle = ac; c.fillRect(0, 2, w, 3)
                    } else if (e === "term") {
                        c.strokeStyle = tx; c.lineWidth = 2; c.setLineDash([8, 4]); c.beginPath(); c.moveTo(0, 4); c.lineTo(w, 4); c.stroke()
                    } else if (e === "plain") {
                        c.fillStyle = tx; c.fillRect(0, 3, w, 1)
                    } else {
                    c.strokeStyle = tx; c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round"
                    c.beginPath(); c.moveTo(1, 4)
                    for (var x = 8; x < width; x += 8) c.lineTo(x, 4 + Math.sin(x * 0.07) * 1.2 + Math.sin(x * 0.31) * 0.6)
                    c.stroke()
                    }
                }
            }
            SnailArt { th: page.th; anchors { left: rule.right; leftMargin: 2; verticalCenter: rule.verticalCenter; verticalCenterOffset: -8 } }

            Head { y: 82; label: "Folders"; ruleX: 74 }
            Row {
                id: fRow
                y: 116; width: parent.width
                Repeater {
                    model: page.folders
                    Item {
                        required property string modelData
                        readonly property string p: app.home + "/" + modelData
                        width: fRow.width / page.folders.length; height: 104
                        FolderArt { th: page.th; anchors { top: parent.top; horizontalCenter: parent.horizontalCenter } }
                        Text {
                            anchors { top: parent.top; topMargin: 62; horizontalCenter: parent.horizontalCenter }
                            text: modelData; color: th.text; font.family: th.sans; font.pixelSize: 12; font.weight: Font.Medium
                        }
                        Text {
                            anchors { top: parent.top; topMargin: 80; horizontalCenter: parent.horizontalCenter }
                            property int n: app.counts[p] !== undefined ? app.counts[p] : 0
                            text: n + (n === 1 ? " item" : " items"); color: th.textMuted
                            font.family: page.paper ? th.serif : page.hf; font.italic: page.paper; font.pixelSize: 10
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.openPath(p) }
                    }
                }
            }

            Head { y: 236; label: "Drives"; ruleX: 60 }
            Flickable {
                y: 266; width: parent.width; height: 140
                contentWidth: dRow.width; contentHeight: height; clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: dRow
                    spacing: 14
                    Repeater {
                        model: app.drives
                        Item {
                            id: wrap
                            required property var modelData
                            width: card.width * page.cardScale; height: card.height * page.cardScale
                        Rectangle {
                            id: card
                            property var modelData: wrap.modelData
                            scale: page.cardScale; transformOrigin: Item.TopLeft
                            readonly property int pc: page.pct(modelData)
                            readonly property color tone: pc >= 85 ? th.accent : th.textMuted
                            width: Math.max(170, (page.width - 28) / 3 / page.cardScale - 6); height: 156; radius: th.radiusCard + 2
                            readonly property bool grad: page.era === "aero" || page.era === "chrome"
                            color: page.era === "term" ? "transparent"
                                 : page.paper ? Qt.alpha(Qt.lighter(th.surface, 1.35), th.surfaceAlpha < 1 ? th.surfaceAlpha * 0.8 : 1)
                                 : Qt.alpha(th.surface, th.surfaceAlpha)
                            gradient: grad ? cardGrad : null
                            Gradient {
                                id: cardGrad
                                GradientStop { position: 0; color: Qt.alpha(Qt.lighter(th.surface, page.era === "aero" ? 1.6 : 1.5), th.surfaceAlpha) }
                                GradientStop { position: page.era === "aero" ? 0.5 : 1; color: Qt.alpha(page.era === "aero" ? th.surface : Qt.darker(th.surface, 1.4), th.surfaceAlpha) }
                                GradientStop { position: 1; color: Qt.alpha(page.era === "aero" ? Qt.lighter(th.surface, 1.15) : Qt.darker(th.surface, 1.4), th.surfaceAlpha) }
                            }
                            border.width: page.era === "luna" ? 2 : 1
                            border.color: page.era === "luna" ? th.accent : page.era === "chrome" ? Qt.alpha(th.accent, 0.7)
                                        : page.era === "term" ? th.textMuted : page.era === "aero" ? Qt.alpha(th.text, 0.25)
                                        : page.era === "plain" ? th.divider : Qt.alpha(th.text, 0.07)
                            Bevel { th: page.th }
                            Rectangle {       // aero glass inner highlight
                                visible: page.era === "aero"; anchors.fill: parent; anchors.margins: 1
                                radius: parent.radius - 1; color: "transparent"; border.width: 1; border.color: Qt.alpha("white", 0.55)
                            }
                            Canvas {          // dashed inner outline (paper only)
                                visible: page.paper
                                anchors.fill: parent; anchors.margins: 6
                                onPaint: {
                                    var c = getContext("2d"); c.reset()
                                    c.strokeStyle = th.divider.toString(); c.lineWidth = 1; c.setLineDash([4, 4])
                                    c.strokeRect(0.5, 0.5, width - 1, height - 1)
                                }
                            }
                            DriveArt { th: page.th; x: 16; y: 16; width: 52; usb: card.modelData.removable }
                            Text {
                                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 10 }
                                text: card.pc + "%"; color: card.pc >= 85 ? th.accent : th.text
                                font.family: page.hf; font.bold: page.boldHead; font.pixelSize: page.era === "term" ? 28 : 34
                            }
                            Text {
                                x: 16; y: 56; width: parent.width - 100; elide: Text.ElideRight
                                text: card.modelData.name; color: th.text; font.family: page.hf; font.bold: page.boldHead; font.pixelSize: page.era === "term" ? 18 : 24
                            }
                            Text {
                                x: 16; y: 88; width: parent.width - 32; elide: Text.ElideRight
                                text: card.modelData.kind; color: th.textMuted; font.family: page.hf; font.italic: page.paper; font.pixelSize: 9
                            }
                            Rectangle {   // Eject (removable drives only)
                                visible: card.modelData.removable && card.modelData.dev !== ""
                                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 66 }
                                width: 64; height: 22; radius: th.radiusPill; color: th.surface
                                border.width: 1; border.color: th.divider
                                Bevel { th: page.th }
                                Row {
                                    anchors.centerIn: parent; spacing: 4
                                    LIcon { th: page.th; size: 8; anchors.verticalCenter: parent.verticalCenter; name: "close"; tint: th.text }
                                    Text { text: "Eject"; color: th.text; font.family: th.sans; font.pixelSize: 10; font.weight: Font.Medium }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(card.modelData.dev) }
                            }
                            Rectangle {   // usage bar, styled per era
                                id: track
                                x: 16; y: 104; width: parent.width - 32
                                height: page.era === "w95" || page.era === "luna" ? 14 : 10
                                radius: page.era === "w95" || page.era === "term" ? 0 : page.era === "luna" ? 4 : th.radiusPill
                                color: page.era === "term" ? "transparent" : page.era === "w95" ? Qt.lighter(th.surface, 1.25) : th.surfaceAlt
                                border.width: page.era === "term" || page.era === "luna" ? 1 : 0
                                border.color: page.era === "luna" ? Qt.alpha(th.text, 0.35) : th.textMuted
                                Bevel { th: page.th; raised: false; visible: page.era === "w95" && th.bevel > 0 }
                                Rectangle {
                                    x: track.border.width; y: track.border.width
                                    width: Math.max(10, (parent.width - 2 * track.border.width) * card.pc / 100)
                                    height: parent.height - 2 * track.border.width
                                    radius: page.era === "w95" || page.era === "term" ? 0 : page.era === "luna" ? 3 : th.radiusPill
                                    color: card.tone; clip: true
                                    Canvas {
                                        anchors.fill: parent
                                        onPaint: {
                                            var c = getContext("2d"); c.reset(); var e = page.era
                                            if (e === "w95" || e === "luna" || e === "term") {      // segmented blocks
                                                c.fillStyle = (e === "term" ? th.surface : track.color).toString()
                                                for (var x = 8; x < width; x += 10) c.fillRect(x, 0, 2, height)
                                            } else if (e === "aero" || e === "chrome") {            // gloss highlight
                                                c.fillStyle = Qt.alpha("white", e === "aero" ? 0.4 : 0.28).toString(); c.fillRect(0, 0, width, height / 2)
                                            } else if (e === "paper") {
                                                c.strokeStyle = Qt.alpha(th.surface, 0.3).toString(); c.lineWidth = 2
                                                for (var y = -height; y < width; y += 6) { c.beginPath(); c.moveTo(y, height); c.lineTo(y + height, 0); c.stroke() }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                x: 16; y: 124
                                text: page.gb(card.modelData.used) + " of " + page.gb(card.modelData.total) + " used"
                                color: th.text; font.family: page.era === "term" ? th.mono : th.sans; font.pixelSize: 9; font.weight: Font.Medium
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 16 }
                                y: 123
                                text: page.gb(card.modelData.free) + " free"
                                color: th.textMuted; font.family: page.hf; font.italic: page.paper; font.pixelSize: 10
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
