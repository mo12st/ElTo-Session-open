// ElTo Worlds manager: the store front-end. Standalone:
//   quickshell -p ManagerWindow.qml
// Five tabs on the approved lapis/amber design; every action goes through
// StoreBridge into store.py / elto-world (data-only, no root). When the
// privileged helper (separate PR) is absent, everything here still works
// at user level.
import Quickshell
import QtQuick

ShellRoot {
    id: app

    ManagerStyle { id: style }
    StoreBridge { id: storeBridge }

    readonly property var tabs: [
        { id: "discover", t: "Discover" },
        { id: "installed", t: "Installed" },
        { id: "updates", t: "Updates" },
        { id: "downloads", t: "Downloads" },
        { id: "customize", t: "Customize" }
    ]
    property string tab: "discover"
    property string category: "worlds"

    FloatingWindow {
        id: win
        title: "ElTo Worlds"
        implicitWidth: 1180; implicitHeight: 760
        minimumSize: Qt.size(980, 620)
        visible: true
        color: style.paper

        Rectangle {
            anchors.fill: parent; radius: style.radius; color: style.paper
            border.width: 1; border.color: style.line; clip: true

            // ---------- header
            Item {
                id: header
                width: parent.width; height: 100
                Text {
                    x: 24; y: 18
                    text: "ElTo Worlds"; color: style.ink; font.pixelSize: 22; font.bold: true
                }
                Row {
                    x: 24; y: 62; spacing: 22
                    Repeater {
                        model: app.tabs
                        Item {
                            required property var modelData
                            width: ttxt.implicitWidth + 4; height: 28
                            Text {
                                id: ttxt; text: modelData.t
                                color: app.tab === modelData.id ? style.ink : style.muted
                                font.pixelSize: 14; font.bold: app.tab === modelData.id
                            }
                            Rectangle {
                                y: 24; width: parent.width; height: 2.5; color: style.accent
                                visible: app.tab === modelData.id
                            }
                            MouseArea { anchors.fill: parent; onClicked: app.tab = modelData.id }
                        }
                    }
                }
                Rectangle { y: 99; width: parent.width; height: 1; color: style.line }
            }

            // ---------- body
            Item {
                y: header.height; width: parent.width; height: parent.height - header.height

                Rectangle {
                    id: side
                    width: 190; height: parent.height; color: "transparent"
                    visible: app.tab === "discover"
                    SidebarNav {
                        x: 14; y: 14; width: parent.width - 24
                        st: style
                        selected: app.category
                        onPicked: function (id) { app.category = id }
                    }
                }
                Rectangle {
                    visible: side.visible
                    x: side.width; width: 1; height: parent.height; color: style.line
                }

                Loader {
                    x: side.visible ? side.width + 1 : 0
                    width: parent.width - x; height: parent.height
                    sourceComponent: app.tab === "discover" ? discoverC
                        : app.tab === "installed" ? installedC
                        : app.tab === "updates" ? updatesC
                        : app.tab === "downloads" ? downloadsC : customizeC
                }
            }
        }
    }

    Component { id: discoverC; DiscoverPage { st: style; bridge: storeBridge; category: app.category } }
    Component { id: installedC; InstalledPage { st: style; bridge: storeBridge } }
    Component { id: updatesC; UpdatesPage { st: style; bridge: storeBridge } }
    Component { id: downloadsC; DownloadsPage { st: style; bridge: storeBridge } }
    Component { id: customizeC; CustomizePage { st: style; bridge: storeBridge } }
}
