// Folder contents in the arrangement of the world's era (shape.folderView): list, details, content, tiles, cards, ls, names.
// The default look (icons) stays in TrailWindow. Same model, same open and select behaviour in every mode.
import QtQuick
import Qt.labs.folderlistmodel

Item {
    id: fv
    required property var win
    required property var fm
    readonly property var th: win.th
    readonly property string mode: win.fview
    property int current: -1
    readonly property bool bandSel: th.cardArt === "band"
    readonly property color selFill: bandSel ? th.selection : th.accent
    readonly property color selText: bandSel ? th.text : (th.lum(th.accent) < 0.5 ? th.surface : th.text)
    onModeChanged: current = -1
    Connections { target: fv.win; function onPathChanged() { fv.current = -1 } }

    function size(b, dir) {
        if (dir) return ""
        if (b < 1024) return b + " B"
        if (b < 1048576) return Math.round(b / 1024) + " KB"
        if (b < 1073741824) return (Math.round(b / 104857.6) / 10) + " MB"
        return (Math.round(b / 107374182.4) / 10) + " GB"
    }
    function kind(dir, suf) { return dir ? "Folder" : (suf !== "" ? suf.toUpperCase() + " file" : "File") }
    function when(d) { return Qt.formatDate(d, "yyyy-MM-dd") }
    function open(i) { win.openEntry(fm.get(i, "filePath"), fm.get(i, "fileIsDir")) }
    function pad(s, n) { s = String(s); return s.length >= n ? s.substring(0, n - 1) + " " : s + " ".repeat(n - s.length) }
    function lpad(s, n) { s = String(s); return s.length >= n ? s : " ".repeat(n - s.length) + s }

    // icon used by every mode
    component Ico: Item {
        id: ic
        property bool dir
        property string nm
        property real s: 32
        property bool sel
        width: s; height: s
        FolderArt { visible: ic.dir; th: fv.th; width: ic.s; height: ic.s * 0.875; anchors.centerIn: parent }
        LIcon { visible: !ic.dir; th: fv.th; size: Math.round(ic.s * 0.6); anchors.centerIn: parent; name: win.fileIcon(ic.nm); tint: ic.sel ? th.onSel() : th.text }
    }
    component Hit: MouseArea {
        property int idx
        property alias hov: self.containsMouse
        id: self
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { fv.current = idx; fv.forceActiveFocus() }
        onDoubleClicked: fv.open(idx)
    }
    Keys.onReturnPressed: if (current >= 0) open(current)

    // ---- list: Win95 style, small icons in columns, status bar ----
    GridView {
        id: vList
        visible: fv.mode === "list"
        anchors { fill: parent; bottomMargin: 28 }
        clip: true; model: visible ? fm : null; flow: GridView.FlowTopToBottom
        cellWidth: 190; cellHeight: 24; boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: d1
            required property int index
            required property string fileName
            required property bool fileIsDir
            readonly property bool sel: fv.current === index
            width: vList.cellWidth; height: vList.cellHeight
            Ico { x: 2; y: 2; s: 20; dir: d1.fileIsDir; nm: d1.fileName; sel: d1.sel }
            Rectangle {
                x: 26; anchors.verticalCenter: parent.verticalCenter; width: lab.width + 6; height: 18
                color: d1.sel ? th.selection : "transparent"; border.width: d1.sel ? 1 : 0; border.color: th.text
                Text { id: lab; anchors.centerIn: parent; text: d1.fileName; color: d1.sel ? th.onSel() : th.text; font.family: th.sans; font.pixelSize: 11 }
            }
            Hit { idx: d1.index }
        }
    }
    Rectangle {
        visible: fv.mode === "list"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 22; color: "transparent"
        Bevel { th: fv.th; raised: false }
        Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: fm.count + " object(s)"; color: th.text; font.family: th.sans; font.pixelSize: 11 }
    }

    // ---- details: header strip and columns (retro95 window look) ----
    Item {
        visible: fv.mode === "details"; anchors.fill: parent
        Rectangle {
            id: dh
            width: parent.width; height: 22
            gradient: Gradient {
                orientation: fv.bandSel ? Gradient.Vertical : Gradient.Horizontal
                GradientStop { position: 0; color: fv.bandSel ? Qt.lighter(th.surface, 1.2) : th.accent }
                GradientStop { position: 1; color: fv.bandSel ? th.surfaceAlt : th.selection } }
            border.width: fv.bandSel ? 1 : 0; border.color: th.divider
            Row { visible: !fv.bandSel; anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } spacing: 3
                Repeater { model: 3; Rectangle { width: 8; height: 8; color: th.surface; border.width: 1; border.color: th.text } } }
            Repeater { model: fv.bandSel ? [parent.width - 262, parent.width - 152, 36] : []; Rectangle { required property real modelData; x: modelData - 8; width: 1; height: parent.height - 6; y: 3; color: th.divider } }
            Text { x: 38; anchors.verticalCenter: parent.verticalCenter; text: "Name"; color: fv.bandSel ? th.text : (win.th.lum(th.accent) < 0.5 ? th.surface : th.text); font.family: fv.bandSel ? th.sans : th.mono; font.bold: true; font.pixelSize: 11 }
            Text { x: parent.width - 260; anchors.verticalCenter: parent.verticalCenter; text: "Size"; color: fv.bandSel ? th.text : (win.th.lum(th.accent) < 0.5 ? th.surface : th.text); font.family: fv.bandSel ? th.sans : th.mono; font.bold: true; font.pixelSize: 11 }
            Text { x: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; text: "Modified"; color: fv.bandSel ? th.text : (win.th.lum(th.accent) < 0.5 ? th.surface : th.text); font.family: fv.bandSel ? th.sans : th.mono; font.bold: true; font.pixelSize: 11 }
        }
        ListView {
            anchors { top: dh.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true; model: parent.visible ? fm : null; boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: d2
                required property int index
                required property string fileName
                required property bool fileIsDir
                required property double fileSize
                required property date fileModified
                readonly property bool sel: fv.current === index
                width: ListView.view.width; height: 30
                color: sel ? th.selection : (index % 2 ? Qt.alpha(th.text, 0.05) : "transparent")
                Ico { x: 10; y: 6; s: 20; dir: d2.fileIsDir; nm: d2.fileName; sel: d2.sel }
                Text { x: 38; anchors.verticalCenter: parent.verticalCenter; text: d2.fileName; color: d2.sel ? th.onSel() : th.text; font.family: fv.bandSel ? th.sans : th.mono; font.pixelSize: 12 }
                Text { x: parent.width - 260; anchors.verticalCenter: parent.verticalCenter; text: fv.size(d2.fileSize, d2.fileIsDir); color: d2.sel ? th.onSel() : th.textMuted; font.family: fv.bandSel ? th.sans : th.mono; font.pixelSize: 11 }
                Text { x: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; text: fv.when(d2.fileModified); color: d2.sel ? th.onSel() : th.textMuted; font.family: fv.bandSel ? th.sans : th.mono; font.pixelSize: 11 }
                Hit { idx: d2.index }
            }
        }
    }

    // ---- content: Win7 style, icon, name, then type, size and date on a second line ----
    ListView {
        id: vContent
        visible: fv.mode === "content"; anchors.fill: parent
        clip: true; model: visible ? fm : null; boundsBehavior: Flickable.StopAtBounds; spacing: 2
        delegate: Rectangle {
            id: d3
            required property int index
            required property string fileName
            required property bool fileIsDir
            required property double fileSize
            required property date fileModified
            required property string fileSuffix
            readonly property bool sel: fv.current === index
            width: vContent.width - 6; height: 52; radius: 4
            color: sel ? Qt.alpha(th.accent, 0.22) : (hit3.hov ? Qt.alpha(th.accent, 0.1) : "transparent")
            border.width: sel || hit3.hov ? 1 : 0; border.color: Qt.alpha(th.accent, sel ? 0.6 : 0.3)
            Rectangle { visible: d3.sel || hit3.hov; anchors { fill: parent; margins: 1 } radius: 3; color: "transparent"; border.width: 1; border.color: Qt.alpha("white", 0.5) }
            Ico { x: 8; y: 6; s: 40; dir: d3.fileIsDir; nm: d3.fileName }
            Text { x: 58; y: 8; text: d3.fileName; color: th.text; font.family: th.sans; font.pixelSize: 13 }
            Text { x: 58; y: 28; text: fv.kind(d3.fileIsDir, d3.fileSuffix) + (d3.fileIsDir ? "" : "   " + fv.size(d3.fileSize, false)) + "   " + fv.when(d3.fileModified); color: th.textMuted; font.family: th.sans; font.pixelSize: 10 }
            Hit { id: hit3; idx: d3.index }
        }
    }

    // ---- tiles: Luna style, two columns, icon left, name and type/size beside it ----
    GridView {
        id: vTiles
        visible: fv.mode === "tiles"; anchors.fill: parent
        clip: true; model: visible ? fm : null; boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / 2); cellHeight: 62
        delegate: Item {
            id: d4
            required property int index
            required property string fileName
            required property bool fileIsDir
            required property double fileSize
            required property string fileSuffix
            readonly property bool sel: fv.current === index
            width: vTiles.cellWidth; height: vTiles.cellHeight
            Rectangle {
                anchors { fill: parent; margins: 3 } radius: 12
                color: d4.sel ? fv.selFill : (hit4.hov ? Qt.alpha(th.accent, 0.15) : "transparent")
                border.width: d4.sel ? 2 : 0; border.color: Qt.alpha("white", 0.9)
                Ico { x: 8; y: 5; s: 44; dir: d4.fileIsDir; nm: d4.fileName }
                Text { x: 62; y: 10; width: parent.width - 70; elide: Text.ElideRight; text: d4.fileName; font.bold: true; font.family: th.sans; font.pixelSize: 13
                    color: d4.sel ? fv.selText : th.text }
                Text { x: 62; y: 30; text: fv.kind(d4.fileIsDir, d4.fileSuffix) + (d4.fileIsDir ? "" : ", " + fv.size(d4.fileSize, false)); font.family: th.sans; font.pixelSize: 10
                    color: d4.sel ? fv.selText : th.textMuted }
            }
            Hit { id: hit4; idx: d4.index }
        }
    }

    // ---- cards: chrome style, angular cards with an accent edge ----
    GridView {
        id: vCards
        visible: fv.mode === "cards"; anchors.fill: parent
        clip: true; model: visible ? fm : null; boundsBehavior: Flickable.StopAtBounds
        cellWidth: 132; cellHeight: 104
        delegate: Item {
            id: d5
            required property int index
            required property string fileName
            required property bool fileIsDir
            required property double fileSize
            readonly property bool sel: fv.current === index
            width: vCards.cellWidth; height: vCards.cellHeight
            Rectangle {
                anchors { fill: parent; margins: 4 } radius: 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(th.surface, d5.sel ? 2 : 1.5) }
                    GradientStop { position: 1; color: Qt.darker(th.surface, 1.5) } }
                border.width: 1; border.color: d5.sel || hit5.hov ? th.accent : Qt.alpha(th.accent, 0.35)
                Rectangle { width: 4; height: parent.height; color: th.accent; visible: d5.sel }
                Rectangle { width: parent.width; height: 2; y: parent.height - 2; color: th.accent; opacity: d5.sel ? 1 : 0.4 }
                Ico { anchors.horizontalCenter: parent.horizontalCenter; y: 8; s: 44; dir: d5.fileIsDir; nm: d5.fileName }
                Text { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 58 } width: parent.width - 10; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                    text: d5.fileName.toUpperCase(); color: th.text; font.family: th.sans; font.bold: true; font.letterSpacing: 1; font.pixelSize: 10 }
                Text { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 74 } text: d5.fileIsDir ? "FOLDER" : fv.size(d5.fileSize, false).toUpperCase()
                    color: th.accent; font.family: th.sans; font.pixelSize: 9; font.letterSpacing: 1 }
            }
            Hit { id: hit5; idx: d5.index }
        }
    }

    // ---- ls: terminal style, ls -l lines in monospace ----
    ListView {
        id: vLs
        visible: fv.mode === "ls"; anchors.fill: parent
        clip: true; model: visible ? fm : null; boundsBehavior: Flickable.StopAtBounds
        header: Text { text: "total " + fm.count; color: th.textMuted; font.family: th.mono; font.pixelSize: 12; height: 20 }
        delegate: Item {
            id: d6
            required property int index
            required property string fileName
            required property bool fileIsDir
            required property double fileSize
            required property date fileModified
            readonly property bool sel: fv.current === index
            width: vLs.width; height: 20
            Rectangle { anchors.fill: parent; color: d6.sel ? th.text : (hit6.hov ? Qt.alpha(th.accent, 0.15) : "transparent") }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (d6.fileIsDir ? "drwxr-xr-x" : "-rw-r--r--") + "  " + fv.lpad(d6.fileIsDir ? "-" : fv.size(d6.fileSize, false), 9) + "  " + fv.when(d6.fileModified) + "  " + d6.fileName + (d6.fileIsDir ? "/" : "")
                color: d6.sel ? th.surface : (d6.fileIsDir ? th.accent : th.text); font.family: th.mono; font.pixelSize: 12
            }
            Hit { id: hit6; idx: d6.index }
        }
    }

    // ---- names: mono style, large light names with size on the right, no icons ----
    ListView {
        id: vNames
        visible: fv.mode === "names"; anchors.fill: parent
        clip: true; model: visible ? fm : null; boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: d7
            required property int index
            required property string fileName
            required property bool fileIsDir
            required property double fileSize
            readonly property bool sel: fv.current === index
            width: vNames.width; height: 40
            Rectangle { width: parent.width; height: 1; y: parent.height - 1; color: th.divider }
            Rectangle { visible: d7.sel; width: 2; height: parent.height - 8; y: 4; color: th.text }
            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: d7.fileName + (d7.fileIsDir ? "  /" : ""); color: th.text
                font.family: th.sans; font.pixelSize: 20; font.weight: d7.sel || hit7.hov ? Font.Normal : Font.Light; font.underline: hit7.hov }
            Text { anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } text: fv.size(d7.fileSize, d7.fileIsDir); color: th.textMuted; font.family: th.sans; font.pixelSize: 11 }
            Hit { id: hit7; idx: d7.index }
        }
    }
}
