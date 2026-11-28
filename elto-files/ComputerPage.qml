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
    readonly property string ca: th.cardArt
    readonly property string layout: th.pageLayout
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
        readonly property bool bar: page.era === "luna" || page.ca === "vapor"
        Rectangle {
            visible: parent.bar; anchors.fill: parent; radius: page.ca === "vapor" ? 0 : 6; height: 22
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: page.ca === "vapor" ? th.accent : Qt.lighter(th.accent, 1.25) }
                GradientStop { position: 1; color: page.ca === "vapor" ? th.selection : th.accent }
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

            Head { visible: page.layout === "cards"; y: 82; label: "Folders"; ruleX: 74 }
            Row {
                id: fRow
                visible: page.layout === "cards"
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

            Head { visible: page.layout === "cards"; y: 236; label: "Drives"; ruleX: 60 }
            Flickable {
                visible: page.layout === "cards"
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
                            readonly property string ca: page.ca
                            readonly property color tone: pc >= 85 ? th.accent : (ca === "plain" || ca === "term" ? th.text : th.textMuted)
                            readonly property bool grad: ca === "aero" || ca === "chrome" || ca === "pearl"
                            width: Math.max(170, (page.width - 28) / 3 / page.cardScale - 6); height: 156
                            radius: ca === "w95" || ca === "vapor" || ca === "term" || ca === "plain" ? 0 : ca === "pearl" ? 28 : ca === "chrome" ? 3 : th.radiusCard + 2
                            color: ca === "term" || ca === "plain" ? "transparent"
                                 : ca === "paper" ? Qt.alpha(Qt.lighter(th.surface, 1.35), th.surfaceAlpha < 1 ? th.surfaceAlpha * 0.8 : 1)
                                 : Qt.alpha(th.surface, th.surfaceAlpha)
                            gradient: grad ? cardGrad : null
                            Gradient {
                                id: cardGrad
                                GradientStop { position: 0; color: Qt.alpha(Qt.lighter(th.surface, card.ca === "chrome" ? 1.5 : 1.7), th.surfaceAlpha) }
                                GradientStop { position: card.ca === "chrome" ? 1 : 0.5; color: Qt.alpha(card.ca === "chrome" ? Qt.darker(th.surface, 1.5) : th.surface, th.surfaceAlpha) }
                                GradientStop { position: 1; color: Qt.alpha(card.ca === "chrome" ? Qt.darker(th.surface, 1.5) : Qt.lighter(th.surface, card.ca === "pearl" ? 1.3 : 1.15), th.surfaceAlpha) }
                            }
                            border.width: ca === "vapor" || ca === "pearl" ? 2 : ca === "plain" || ca === "w95" ? 0 : 1
                            border.color: ca === "vapor" ? th.text : ca === "pearl" ? Qt.alpha("white", 0.8) : ca === "chrome" ? Qt.alpha(th.accent, 0.8)
                                        : ca === "term" ? th.textMuted : ca === "aero" ? Qt.alpha(th.text, 0.25) : Qt.alpha(th.text, 0.07)
                            Rectangle {       // vapor: hard offset shadow behind the card
                                visible: card.ca === "vapor"; z: -1; x: 5; y: 5; width: parent.width; height: parent.height; color: Qt.alpha(th.text, 0.4)
                            }
                            Bevel { th: page.th }
                            Rectangle {       // aero / pearl glass inner highlight
                                visible: card.ca === "aero" || card.ca === "pearl"; anchors.fill: parent; anchors.margins: 1
                                radius: parent.radius - 1; color: "transparent"; border.width: 1; border.color: Qt.alpha("white", 0.55)
                            }
                            Rectangle {       // vapor: title-bar strip with window squares
                                visible: card.ca === "vapor"; x: 0; y: 0; width: parent.width; height: 11
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: th.accent }
                                    GradientStop { position: 1; color: th.selection } }
                                Row { anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } spacing: 3
                                    Repeater { model: 3; Rectangle { width: 6; height: 6; color: th.surface; border.width: 1; border.color: th.text } } }
                            }
                            Rectangle {       // plain: single top rule
                                visible: card.ca === "plain"; x: 0; y: 0; width: parent.width; height: 2; color: th.text
                            }
                            Rectangle {       // chrome: accent edge
                                visible: card.ca === "chrome"; x: 0; y: 0; width: 4; height: parent.height; color: th.accent
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
                            // percentage: its own style per card art
                            Rectangle {
                                visible: card.ca === "pearl"; width: 50; height: 50; radius: 25; color: card.pc >= 85 ? th.accent : th.surfaceAlt
                                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 8 }
                                border.width: 2; border.color: Qt.alpha("white", 0.9)
                            }
                            Text {
                                id: pcText
                                anchors { right: parent.right; rightMargin: card.ca === "pearl" ? 23 : 16; top: parent.top; topMargin: card.ca === "pearl" ? 22 : card.ca === "term" ? 14 : 10 }
                                text: card.ca === "term" ? "[" + card.pc + "%]" : card.pc + "%"
                                color: card.ca === "pearl" ? (card.pc >= 85 ? page.accentText : th.text) : card.pc >= 85 ? th.accent : th.text
                                font.family: card.ca === "vapor" || card.ca === "term" ? th.mono : card.ca === "paper" ? th.serif : th.sans
                                font.bold: card.ca === "w95" || card.ca === "chrome" || card.ca === "pearl" || card.ca === "vapor"
                                font.weight: card.ca === "aero" || card.ca === "plain" ? Font.Light : font.weight
                                font.letterSpacing: card.ca === "chrome" ? 1 : 0
                                font.pixelSize: card.ca === "pearl" ? 16 : card.ca === "w95" ? 24 : card.ca === "term" ? 22 : card.ca === "aero" ? 40 : 34
                            }
                            Text {
                                x: 16; y: 56; width: parent.width - 100; elide: Text.ElideRight
                                text: card.modelData.name; color: th.text
                                font.family: card.ca === "paper" ? th.serif : card.ca === "term" || card.ca === "vapor" ? th.mono : th.sans
                                font.bold: card.ca === "w95" || card.ca === "pearl" || card.ca === "chrome"
                                font.capitalization: card.ca === "chrome" ? Font.AllUppercase : Font.MixedCase
                                font.letterSpacing: card.ca === "chrome" ? 1.5 : 0
                                font.pixelSize: card.ca === "term" || card.ca === "w95" || card.ca === "chrome" ? 17 : 24
                            }
                            Text {
                                x: 16; y: 88; width: parent.width - 32; elide: Text.ElideRight
                                text: card.modelData.kind; color: th.textMuted; font.family: page.hf; font.italic: page.paper; font.pixelSize: 9
                            }
                            Rectangle {   // Eject (removable drives only), styled per card art
                                id: ej
                                visible: card.modelData.removable && card.modelData.dev !== ""
                                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 66 }
                                width: card.ca === "term" || card.ca === "plain" ? 64 : 64; height: 22
                                radius: card.ca === "w95" || card.ca === "vapor" || card.ca === "term" || card.ca === "plain" ? 0 : card.ca === "chrome" ? 2 : th.radiusPill
                                readonly property bool filled: card.ca === "vapor" || card.ca === "pearl"
                                color: card.ca === "term" || card.ca === "plain" || card.ca === "chrome" ? "transparent" : filled ? th.accent : th.surface
                                border.width: card.ca === "w95" || card.ca === "plain" ? 0 : card.ca === "vapor" ? 2 : 1
                                border.color: card.ca === "vapor" ? th.text : card.ca === "chrome" ? th.accent : card.ca === "term" ? th.textMuted : card.ca === "pearl" ? Qt.alpha("white", 0.9) : th.divider
                                Bevel { th: page.th }
                                Rectangle { visible: card.ca === "aero" || card.ca === "pearl"; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 2 } height: parent.height / 2 - 2; radius: height / 2; color: Qt.alpha("white", 0.4) }
                                Row {
                                    anchors.centerIn: parent; spacing: 4
                                    LIcon { visible: card.ca !== "term" && card.ca !== "plain"; th: page.th; size: 8; anchors.verticalCenter: parent.verticalCenter; name: "close"; tint: ej.filled ? page.accentText : th.text }
                                    Text {
                                        text: card.ca === "term" ? "[ eject ]" : "Eject"
                                        color: ej.filled ? page.accentText : card.ca === "chrome" ? th.accent : th.text
                                        font.family: card.ca === "term" || card.ca === "vapor" ? th.mono : th.sans; font.pixelSize: 10
                                        font.weight: card.ca === "plain" ? Font.Normal : Font.Medium; font.bold: card.ca === "w95"
                                        font.underline: card.ca === "plain"
                                        font.capitalization: card.ca === "chrome" ? Font.AllUppercase : Font.MixedCase
                                        font.letterSpacing: card.ca === "chrome" ? 1 : 0
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.eject(card.modelData.dev) }
                            }
                            Text {        // term: ASCII capacity bar
                                visible: card.ca === "term"
                                x: 16; y: 102; font.family: th.mono; font.pixelSize: 11; color: card.tone
                                text: "[" + "#".repeat(Math.round(card.pc / 5)) + "-".repeat(20 - Math.round(card.pc / 5)) + "]"
                            }
                            Rectangle {   // usage bar, styled per card art
                                id: track
                                visible: card.ca !== "term"
                                x: 16; y: card.ca === "plain" ? 108 : 104; width: parent.width - 32
                                height: card.ca === "pearl" ? 16 : card.ca === "w95" || card.ca === "vapor" ? 14 : card.ca === "plain" ? 2 : card.ca === "chrome" ? 6 : 10
                                radius: card.ca === "w95" || card.ca === "vapor" || card.ca === "plain" || card.ca === "chrome" ? 0 : th.radiusPill
                                color: card.ca === "w95" ? Qt.lighter(th.surface, 1.25) : card.ca === "plain" ? th.divider : th.surfaceAlt
                                border.width: card.ca === "vapor" ? 2 : card.ca === "chrome" ? 1 : 0
                                border.color: card.ca === "vapor" ? th.text : th.accent
                                Bevel { th: page.th; raised: false; visible: card.ca === "w95" && th.bevel > 0 }
                                Rectangle {
                                    x: track.border.width; y: track.border.width
                                    width: Math.max(card.ca === "plain" ? 2 : 10, (parent.width - 2 * track.border.width) * card.pc / 100)
                                    height: parent.height - 2 * track.border.width
                                    radius: track.radius > 0 ? th.radiusPill : 0
                                    color: card.tone; clip: true
                                    Canvas {
                                        anchors.fill: parent
                                        onPaint: {
                                            var c = getContext("2d"); c.reset(); var e = card.ca
                                            if (e === "w95" || e === "chrome") {
                                                c.fillStyle = track.color.toString(); var st = e === "w95" ? 10 : 5
                                                for (var x = st - 2; x < width; x += st) c.fillRect(x, 0, 2, height)
                                            } else if (e === "aero" || e === "pearl") {
                                                c.fillStyle = Qt.alpha("white", e === "pearl" ? 0.5 : 0.4).toString(); c.fillRect(0, 0, width, height / 2)
                                            } else if (e === "vapor") {
                                                c.fillStyle = Qt.alpha(th.surface, 0.5).toString()
                                                for (var y = 0; y < width; y += 8) c.fillRect(y, 0, 4, height)
                                            } else if (e === "paper") {
                                                c.strokeStyle = Qt.alpha(th.surface, 0.3).toString(); c.lineWidth = 2
                                                for (var z = -height; z < width; z += 6) { c.beginPath(); c.moveTo(z, height); c.lineTo(z + height, 0); c.stroke() }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                x: 16; y: 124
                                text: page.gb(card.modelData.used) + " of " + page.gb(card.modelData.total) + " used"
                                color: th.text; font.family: card.ca === "term" || card.ca === "vapor" ? th.mono : th.sans; font.pixelSize: 9; font.weight: Font.Medium
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
            Loader {
                id: body
                x: 0; y: 74; width: parent.width; height: parent.height - 74 - 8
                readonly property string file: ({ grid: "CompGrid", rows: "CompRows", tiles: "CompTiles", gauge: "CompGauge", table: "CompTable", columns: "CompColumns", windows: "CompWindows", desktop: "CompDesktop" })[page.layout] || ""
                function load() { if (file !== "") setSource(file + ".qml", { page: page }); else source = "" }
                Component.onCompleted: load()
                onFileChanged: load()
            }
    }
}
