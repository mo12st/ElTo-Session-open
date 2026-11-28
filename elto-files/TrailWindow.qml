// Trail window: sidebar, back/forward, breadcrumb pill, folder and file grid.
import Quickshell
import QtQuick
import Qt.labs.folderlistmodel

FloatingWindow {
    id: win
    required property var app
    readonly property var th: app.theme
    title: "Trail"
    implicitWidth: 860; implicitHeight: 540
    minimumSize: Qt.size(560, 380)
    color: "transparent"
    visible: app.trailVisible
    onVisibleChanged: app.trailVisible = visible

    // Soft content corners. The window frame (Aurorae) must follow this one value; do not change it here without the frame.
    readonly property int contentRadius: th.radiusWindow
    readonly property string computerPath: "computer:"
    readonly property bool computerMode: path === computerPath
    property string path: app.start === "computer" ? computerPath : app.home
    property var hist: [path]
    property int hi: 0

    function go(p) {
        if (p === path) return
        hist = hist.slice(0, hi + 1).concat([p]); hi = hist.length - 1; path = p
    }
    function back() { if (hi > 0) { hi--; path = hist[hi] } }
    function forward() { if (hi < hist.length - 1) { hi++; path = hist[hi] } }
    function openEntry(p, isDir) { if (isDir) go(p); else app.openFile(p) }
    Connections {
        target: app
        function onGotoSerialChanged() { win.go(app.trailGoto) }
    }
    Component.onCompleted: if (app.start.indexOf("/") === 0) { hist = [app.trailGoto]; path = app.trailGoto }

    readonly property var places: [
        { label: "Home", icon: "home", path: app.home },
        { label: "Documents", icon: "docs", path: app.home + "/Documents" },
        { label: "Downloads", icon: "downloads", path: app.home + "/Downloads" },
        { label: "Pictures", icon: "pictures", path: app.home + "/Pictures" },
        { label: "Trash", icon: "trash", path: app.home + "/.local/share/Trash/files" }
    ]
    readonly property var crumbs: {
        var out = [], base, rest
        if (path === computerPath) return [{ label: "This computer", path: computerPath }]
        if (path === app.home || path.indexOf(app.home + "/") === 0) {
            out.push({ label: "Home", path: app.home }); base = app.home; rest = path.slice(app.home.length)
        } else { out.push({ label: "/", path: "/" }); base = ""; rest = path }
        var parts = rest.split("/").filter(function (s) { return s.length > 0 })
        var acc = base
        for (var i = 0; i < parts.length; i++) { acc += "/" + parts[i]; out.push({ label: parts[i], path: acc }) }
        return out
    }
    readonly property string folderTitle: {
        if (path === app.home) return "Home"
        if (path === app.home + "/.local/share/Trash/files") return "Trash"
        var i = path.lastIndexOf("/"); return path === "/" ? "/" : path.slice(i + 1)
    }
    function fileIcon(name) {
        var e = name.lastIndexOf(".") >= 0 ? name.slice(name.lastIndexOf(".") + 1).toLowerCase() : ""
        if (e === "pdf") return "file-pdf"
        if (["md", "txt", "log", "odt", "doc", "docx", "rtf"].indexOf(e) >= 0) return "file-text"
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(e) >= 0) return "file-zip"
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif"].indexOf(e) >= 0) return "file-image"
        return "file-generic"
    }

    Rectangle {
        anchors.fill: parent
        radius: win.contentRadius; color: Qt.alpha(th.surface, th.surfaceAlpha); clip: true
        border.width: 1; border.color: th.divider
        focus: true
        Bevel { th: win.th; z: 10 }
        Rectangle {   // glass sheen, only when the theme asks for glass
            visible: th.glass; z: 9; anchors.fill: parent; radius: win.contentRadius
            border.width: 1; border.color: Qt.alpha(th.surface, 0.85)
            gradient: Gradient { GradientStop { position: 0; color: Qt.alpha(th.surface, 0.35) } GradientStop { position: 0.35; color: "transparent" } }
        }
        Keys.onPressed: function (ev) {
            if (ev.key === Qt.Key_Backspace || (ev.modifiers & Qt.AltModifier && ev.key === Qt.Key_Left)) { win.back(); ev.accepted = true }
            else if (ev.modifiers & Qt.AltModifier && ev.key === Qt.Key_Right) { win.forward(); ev.accepted = true }
        }

        // ---- sidebar: look and arrangement follow the world's card art (shape.cardArt) ----
        Rectangle {
            id: side
            readonly property string ca: th.cardArt
            readonly property color sideCol: ca === "paper" ? Qt.alpha(Qt.darker(th.surface, 1.025), th.surfaceAlpha)
                : ca === "w95" ? th.surface
                : ca === "vapor" ? Qt.darker(th.surface, 1.1)
                : ca === "aero" ? Qt.alpha(Qt.lighter(th.surface, 1.12), th.surfaceAlpha)
                : ca === "pearl" ? Qt.alpha(Qt.lighter(th.surface, 1.1), th.surfaceAlpha)
                : ca === "band" ? Qt.lighter(th.selection, 1.08)
                : ca === "chrome" ? Qt.darker(th.surface, 1.35)
                : ca === "term" ? "transparent" : "transparent"
            width: 176; height: parent.height
            color: "transparent"
            Rectangle { anchors.fill: parent; radius: win.contentRadius; color: side.sideCol }
            Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: win.contentRadius; color: side.sideCol }
            Rectangle {   // right edge line, per era
                visible: side.ca !== "paper"
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: side.ca === "vapor" || side.ca === "pearl" ? 2 : 1
                color: side.ca === "chrome" ? th.accent : side.ca === "vapor" ? th.text : side.ca === "pearl" ? Qt.alpha("white", 0.9) : side.ca === "w95" ? Qt.darker(th.surface, 1.8) : side.ca === "term" ? th.textMuted : th.divider
            }
            Rectangle {   // glass sheen at the top of aero and pearl panes
                visible: side.ca === "aero" || side.ca === "pearl"; width: parent.width; height: parent.height / 3; radius: win.contentRadius
                gradient: Gradient { GradientStop { position: 0; color: Qt.alpha("white", 0.35) } GradientStop { position: 1; color: "transparent" } }
            }
            Column {
                x: side.ca === "w95" || side.ca === "term" ? 6 : 12; y: 16; width: parent.width - (side.ca === "w95" || side.ca === "term" ? 12 : 24)
                spacing: side.ca === "w95" || side.ca === "term" ? 0 : side.ca === "paper" ? 4 : 3
                SideHead { label: "Computer" }
                SideRow { label: "This computer"; icon: "computer"; selected: win.computerMode; onClicked: win.go(win.computerPath) }
                SideHead { label: "Places" }
                Repeater {
                    model: win.places
                    SideRow {
                        required property var modelData
                        label: modelData.label; icon: modelData.icon
                        selected: win.path === modelData.path
                        onClicked: win.go(modelData.path)
                    }
                }
            }
        }

        // ---- main ----
        Item {
            anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 20; leftMargin: 20; topMargin: 16 }

            Row {
                id: bar
                width: parent.width; height: 32; spacing: 8
                NavBtn { icon: "chev-left"; enabled: win.hi > 0; onClicked: win.back() }
                NavBtn { icon: "chev-right"; enabled: win.hi < win.hist.length - 1; onClicked: win.forward() }
                Rectangle {
                    width: parent.width - 80; height: 32; radius: th.radiusPill; color: th.surfaceAlt
                    clip: true
                    Bevel { th: win.th; raised: false }
                    Row {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Repeater {
                            model: win.crumbs
                            Row {
                                required property int index
                                required property var modelData
                                spacing: 6
                                Text {
                                    visible: index > 0; text: "/"; color: th.textMuted
                                    font.family: th.sans; font.pixelSize: 12
                                }
                                Text {
                                    text: modelData.label; color: th.text
                                    font.family: th.sans; font.pixelSize: 12; font.weight: Font.Medium
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.go(modelData.path) }
                                }
                            }
                        }
                    }
                }
            }

            ComputerPage {
                visible: win.computerMode
                anchors { top: bar.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
                app: win.app
            }
            Text {
                id: heading
                visible: !win.computerMode
                anchors { top: bar.bottom; topMargin: 14; left: parent.left }
                text: win.folderTitle; color: th.text
                font.family: th.cardArt === "paper" ? th.serif : th.cardArt === "term" || th.cardArt === "vapor" ? th.mono : th.sans
                font.bold: th.cardArt === "w95" || th.cardArt === "pearl" || th.cardArt === "chrome" || th.cardArt === "band"; font.weight: th.cardArt === "plain" || th.cardArt === "aero" ? Font.Light : font.weight
                font.capitalization: th.cardArt === "chrome" ? Font.AllUppercase : Font.MixedCase; font.pixelSize: 28; renderType: Text.NativeRendering
            }
            Rectangle { id: rule; visible: !win.computerMode; anchors { top: heading.bottom; topMargin: 4; left: parent.left; right: parent.right } height: 1; color: th.divider }

            FolderListModel {
                id: fm
                folder: "file://" + (win.computerMode ? app.home : win.path)
                showDirsFirst: true; showDotAndDotDot: false; showHidden: false
                sortField: FolderListModel.Name; caseSensitive: false
            }
            FolderViews {
                visible: !win.computerMode && th.folderView !== "icons"
                win: win; fm: fm
                anchors { top: rule.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
            }
            GridView {
                id: grid
                visible: !win.computerMode && th.folderView === "icons"
                anchors { top: rule.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
                clip: true; model: fm; cellWidth: 120; cellHeight: 112
                currentIndex: -1; boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: cell
                    required property int index
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    width: grid.cellWidth; height: grid.cellHeight
                    readonly property bool sel: grid.currentIndex === index
                    Rectangle {
                        id: tile
                        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                        width: cell.fileIsDir ? 84 : 56; height: cell.fileIsDir ? 78 : 56
                        y: cell.fileIsDir ? 0 : 11
                        radius: th.radiusCard
                        color: cell.sel ? th.selection : (cell.fileIsDir ? "transparent" : th.surfaceAlt)
                        Behavior on color { ColorAnimation { duration: th.ms(120) } }
                        Bevel { th: win.th; visible: !cell.fileIsDir && th.bevel > 0 }
                        FolderArt { th: win.th; visible: cell.fileIsDir; anchors.centerIn: parent }
                        LIcon { th: win.th; visible: !cell.fileIsDir; anchors.centerIn: parent; size: 26; name: win.fileIcon(cell.fileName); tint: cell.sel ? th.onSel() : th.text }
                    }
                    Text {
                        anchors { top: tile.bottom; topMargin: cell.fileIsDir ? 2 : 8; horizontalCenter: parent.horizontalCenter }
                        width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                        text: cell.fileName; color: th.text; font.family: th.sans; font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: grid.currentIndex = cell.index
                        onDoubleClicked: win.openEntry(cell.filePath, cell.fileIsDir)
                    }
                }
                Keys.onReturnPressed: if (currentIndex >= 0) {
                    win.openEntry(fm.get(currentIndex, "filePath"), fm.get(currentIndex, "fileIsDir"))
                }
                onModelChanged: currentIndex = -1
            }
            Connections { target: win; function onPathChanged() { grid.currentIndex = -1 } }
            Text {
                visible: !win.computerMode && fm.count === 0 && fm.status === FolderListModel.Ready
                anchors.centerIn: grid; text: "Nothing here"; color: th.textMuted
                font.family: th.serif; font.italic: true; font.pixelSize: 15
            }
        }
    }

    component SideHead: Item {
        property string label
        readonly property string ca: th.cardArt
        visible: ca !== "paper" && ca !== "w95"
        width: parent.width; height: visible ? (ca === "pearl" ? 26 : 24) : 0
        Rectangle {   // pearl: gradient bar, vapor: title strip
            visible: parent.ca === "pearl" || parent.ca === "vapor" || parent.ca === "band"; anchors.fill: parent; anchors.topMargin: 2
            radius: parent.ca === "pearl" || parent.ca === "band" ? 8 : 0
            gradient: Gradient {
                orientation: parent.parent.ca === "band" ? Gradient.Vertical : Gradient.Horizontal
                GradientStop { position: 0; color: parent.parent.ca === "band" ? th.bandTop : parent.parent.ca === "pearl" ? Qt.lighter(th.accent, 1.3) : th.accent }
                GradientStop { position: 1; color: parent.parent.ca === "band" ? th.bandBottom : parent.parent.ca === "pearl" ? th.accent : th.selection } }
        }
        Text {
            id: ht
            x: parent.ca === "pearl" || parent.ca === "vapor" || parent.ca === "band" ? 8 : 4; anchors.verticalCenter: parent.verticalCenter
            text: parent.ca === "term" ? "# " + parent.label.toLowerCase() : parent.ca === "chrome" ? "// " + parent.label : parent.label
            color: parent.ca === "band" ? th.surface : parent.ca === "pearl" || parent.ca === "vapor" ? page_accentText() : parent.ca === "aero" ? Qt.darker(th.accent, 1.5) : parent.ca === "chrome" ? th.accent : th.textMuted
            font.family: parent.ca === "term" || parent.ca === "vapor" ? th.mono : th.sans
            font.pixelSize: parent.ca === "aero" || parent.ca === "band" ? 12 : 10
            font.bold: parent.ca === "pearl" || parent.ca === "chrome" || parent.ca === "vapor" || parent.ca === "band"
            font.capitalization: parent.ca === "chrome" || parent.ca === "plain" ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: parent.ca === "chrome" ? 2 : parent.ca === "plain" ? 1.5 : 0
        }
        Rectangle {   // aero: fading rule
            visible: parent.ca === "aero"; x: ht.width + 12; y: 12; width: parent.width - x; height: 1
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(th.accent, 0.6) }
                GradientStop { position: 1; color: Qt.alpha(th.accent, 0) } }
        }
    }
    function page_accentText() { return th.lum(th.accent) < 0.5 ? th.surface : th.text }
    component SideRow: Rectangle {
        id: row
        property string label
        property string icon
        property bool selected
        readonly property string ca: th.cardArt
        readonly property bool solidSel: ca === "paper" || ca === "w95" || ca === "vapor" || ca === "term"
        readonly property color fg: !selected ? th.text : ca === "term" ? th.surface : solidSel ? th.onSel() : ca === "pearl" ? page_accentText() : th.text
        signal clicked()
        width: parent.width
        height: ca === "band" ? 30 : ca === "w95" ? 26 : ca === "term" ? 22 : ca === "aero" ? 30 : ca === "vapor" ? 28 : ca === "plain" ? 30 : ca === "paper" ? 34 : 32
        radius: ca === "paper" ? th.radiusCard : ca === "band" ? 6 : ca === "aero" ? 4 : ca === "pearl" ? height / 2 : ca === "chrome" ? 2 : 0
        color: selected ? (ca === "band" ? th.selection : ca === "term" ? th.text : solidSel ? th.selection : ca === "pearl" ? th.accent : ca === "chrome" ? Qt.alpha(th.accent, 0.2) : ca === "aero" ? Qt.alpha(th.accent, 0.22) : "transparent")
                        : (ma.containsMouse ? Qt.alpha(ca === "aero" || ca === "pearl" || ca === "chrome" || ca === "band" ? th.accent : th.text, ca === "paper" ? 0.06 : 0.12) : "transparent")
        border.width: selected ? (ca === "w95" || ca === "aero" || ca === "band" ? 1 : ca === "vapor" ? 2 : 0) : (ca === "aero" && ma.containsMouse ? 1 : 0)
        border.color: ca === "band" ? th.bandBottom : ca === "aero" ? Qt.alpha(th.accent, 0.6) : th.text
        Behavior on color { ColorAnimation { duration: th.ms(120) } }
        Rectangle {   // chrome and plain: marker bar on the selected row
            visible: row.selected && (row.ca === "chrome" || row.ca === "plain"); width: row.ca === "chrome" ? 4 : 2; height: parent.height
            color: row.ca === "chrome" ? th.accent : th.text
        }
        LIcon { th: win.th; x: row.ca === "w95" || row.ca === "term" ? 6 : 12; anchors.verticalCenter: parent.verticalCenter; size: row.ca === "w95" ? 15 : 16; name: row.icon; tint: row.fg }
        Text {
            x: row.ca === "w95" ? 28 : row.ca === "term" ? 28 : 38; anchors.verticalCenter: parent.verticalCenter
            text: row.ca === "term" ? (row.selected ? "> " : "  ") + row.label : row.label
            color: row.fg
            font.family: row.ca === "term" || row.ca === "vapor" ? th.mono : th.sans
            font.pixelSize: row.ca === "w95" || row.ca === "chrome" || row.ca === "vapor" ? 11 : row.ca === "term" ? 12 : row.ca === "plain" ? 13 : 12
            font.bold: row.ca === "pearl" || row.ca === "chrome" || (row.ca === "plain" && row.selected)
            font.weight: row.ca === "plain" && !row.selected ? Font.Light : font.weight
            font.capitalization: row.ca === "chrome" ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: row.ca === "chrome" ? 1.5 : 0
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
    }
    component NavBtn: Rectangle {
        id: nb
        property string icon
        signal clicked()
        width: 32; height: 32; radius: th.radiusPill; color: th.surfaceAlt
        opacity: enabled ? 1 : 0.4
        Bevel { th: win.th }
        LIcon { th: win.th; anchors.centerIn: parent; size: 14; name: nb.icon; tint: th.text }
        MouseArea { anchors.fill: parent; enabled: nb.enabled; cursorShape: Qt.PointingHandCursor; onClicked: nb.clicked() }
    }
}
