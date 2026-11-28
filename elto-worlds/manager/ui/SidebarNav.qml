// Store sidebar: sections, categories (incl. the File manager category,
// pending-schema until the per-world block ships), Functions from GitHub.
import QtQuick

Column {
    id: nav
    property var st: ManagerStyle {}
    property string selected: "worlds"
    signal picked(string id)

    spacing: 2
    Repeater {
        model: [
            { id: "worlds", t: "Worlds" },
            { id: "window-frame", t: "Window frames" },
            { id: "color-scheme", t: "Color schemes" },
            { id: "icons", t: "Icons" },
            { id: "cursor", t: "Cursors" },
            { id: "wallpapers", t: "Wallpapers" },
            { id: "sounds", t: "Sounds" },
            { id: "greeter", t: "Greeter" },
            { id: "boot", t: "Boot and splash" },
            { id: "animations", t: "Animations" },
            { id: "widgets", t: "Kvantum" },
            { id: "boot-menu", t: "GRUB menu" },
            { id: "filemanager", t: "File manager (soon)" },
            { id: "functions", t: "Functions - GitHub" }
        ]
        Rectangle {
            required property var modelData
            width: nav.width; height: 30; radius: nav.st.radiusSmall
            color: nav.selected === modelData.id ? nav.st.accent : "transparent"
            Text {
                x: 12; anchors.verticalCenter: parent.verticalCenter
                text: modelData.t
                color: nav.selected === modelData.id ? nav.st.cream : nav.st.ink
                font.pixelSize: 12; font.bold: nav.selected === modelData.id
            }
            MouseArea { anchors.fill: parent; onClicked: nav.picked(modelData.id) }
        }
    }
}
