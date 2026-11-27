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
        radius: th.radiusWindow; color: th.surface; clip: true
        border.width: 1; border.color: th.divider
        focus: true
        Keys.onPressed: function (ev) {
            if (ev.key === Qt.Key_Backspace || (ev.modifiers & Qt.AltModifier && ev.key === Qt.Key_Left)) { win.back(); ev.accepted = true }
            else if (ev.modifiers & Qt.AltModifier && ev.key === Qt.Key_Right) { win.forward(); ev.accepted = true }
        }

        // ---- sidebar ----
        Rectangle {
            id: side
            width: 176; height: parent.height
            color: "transparent"
            Rectangle { anchors.fill: parent; radius: th.radiusWindow; color: Qt.darker(th.surface, 1.025) }
            Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: th.radiusWindow; color: Qt.darker(th.surface, 1.025) }
            Column {
                x: 12; y: 16; width: parent.width - 24; spacing: 4
                SideRow { label: "This computer"; icon: "computer"; selected: win.computerMode; onClicked: win.go(win.computerPath) }
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
                    width: parent.width - 80; height: 32; radius: 16; color: th.surfaceAlt
                    clip: true
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
                font.family: th.serif; font.pixelSize: 28; renderType: Text.NativeRendering
            }
            Rectangle { id: rule; visible: !win.computerMode; anchors { top: heading.bottom; topMargin: 4; left: parent.left; right: parent.right } height: 1; color: th.divider }

            FolderListModel {
                id: fm
                folder: "file://" + (win.computerMode ? app.home : win.path)
                showDirsFirst: true; showDotAndDotDot: false; showHidden: false
                sortField: FolderListModel.Name; caseSensitive: false
            }
            GridView {
                id: grid
                visible: !win.computerMode
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
                        radius: 14
                        color: cell.sel ? th.selection : (cell.fileIsDir ? "transparent" : th.surfaceAlt)
                        Behavior on color { ColorAnimation { duration: th.ms(120) } }
                        Image {
                            anchors.centerIn: parent
                            source: cell.fileIsDir ? app.icon("folder") : app.icon(win.fileIcon(cell.fileName))
                            width: cell.fileIsDir ? 64 : 26; height: cell.fileIsDir ? 56 : 26
                            sourceSize.width: width * 2; sourceSize.height: height * 2
                            asynchronous: true; smooth: true
                        }
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

    component SideRow: Rectangle {
        id: row
        property string label
        property string icon
        property bool selected
        signal clicked()
        width: parent.width; height: 34; radius: 12
        color: selected ? th.selection : (ma.containsMouse ? Qt.rgba(0, 0, 0, 0.04) : "transparent")
        Behavior on color { ColorAnimation { duration: th.ms(120) } }
        Image {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16; sourceSize.width: 32; sourceSize.height: 32
            source: app.icon(row.icon)
        }
        Text {
            x: 38; anchors.verticalCenter: parent.verticalCenter
            text: row.label; color: th.text; font.family: th.sans; font.pixelSize: 12
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
    }
    component NavBtn: Rectangle {
        id: nb
        property string icon
        signal clicked()
        width: 32; height: 32; radius: 16; color: th.surfaceAlt
        opacity: enabled ? 1 : 0.4
        Image {
            anchors.centerIn: parent; width: 14; height: 14
            sourceSize.width: 28; sourceSize.height: 28; source: app.icon(nb.icon)
        }
        MouseArea { anchors.fill: parent; enabled: nb.enabled; cursorShape: Qt.PointingHandCursor; onClicked: nb.clicked() }
    }
}
