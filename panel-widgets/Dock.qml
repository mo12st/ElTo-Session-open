// ElTo bottom island dock (CONCEPT until approved): floating pill with pinned apps,
// a divider, and one pill per open window. Running apps get a selection circle. All look values come from Theme.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: root
    readonly property var dk: Theme.dockT
    // pinned apps: icon (Lucide), command ("" = not wired yet), appid used to match open windows
    readonly property var pinned: [
        { icon: "folder", cmd: "dolphin", appid: "org.kde.dolphin" },
        { icon: "terminal", cmd: "foot", appid: "foot" },
        { icon: "globe", cmd: "", appid: "browser" },
        { icon: "notebook-pen", cmd: "", appid: "notes" },
        { icon: "image", cmd: "", appid: "gallery" },
        { icon: "mail", cmd: "", appid: "mail" },
        { icon: "palette", cmd: "quickshell -p " + Quickshell.shellPath("customize.qml"), appid: "customize" }
    ]
    property string activeApp: ""
    property var openApps: ({})
    Process { id: runner }
    function launch(cmd) { if (cmd !== "") { runner.command = ["sh", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"]; runner.running = true } }

    WindowList { id: wl }
    function refresh() {
        var o = {}, act = ""
        for (var i = 0; i < wl.model.count; i++) {
            var w = wl.model.get(i)
            o[w.appid] = true
            if (w.isActive) act = w.appid
        }
        root.openApps = o; root.activeApp = act
    }
    Connections { target: wl.model; function onCountChanged() { root.refresh() } function onDataChanged() { root.refresh() } }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "elto-dock"
            exclusionMode: ExclusionMode.Ignore
            anchors { bottom: true }
            implicitWidth: Math.max(bar.width + 40, 200)
            implicitHeight: root.dk.height + root.dk.bottomMargin + 24
            color: "transparent"
            mask: Region { item: bar }
            visible: Theme.dockStyle === "island"

            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: bar.x - index * 2; y: bar.y + Theme.shadowOffsetY / 3 - index
                    width: bar.width + index * 4; height: bar.height + index * 4
                    radius: bar.radius + index * 2
                    color: Qt.rgba(0, 0, 0, Theme.shadowAlpha / 18)
                }
            }

            Rectangle {
                id: bar
                height: root.dk.height
                width: row.width + root.dk.pad * 2
                x: (parent.width - width) / 2
                y: parent.height - root.dk.bottomMargin - height
                radius: root.dk.radius
                color: Theme.surface
                Behavior on width { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }

                Row {
                    id: row
                    x: root.dk.pad
                    y: (parent.height - height) / 2
                    spacing: root.dk.gap

                    Repeater {
                        model: root.pinned
                        Item {
                            id: app
                            required property var modelData
                            readonly property bool running: root.openApps[modelData.appid] === true
                            readonly property bool current: root.activeApp === modelData.appid && running
                            width: root.dk.tile; height: root.dk.tile
                            Rectangle {
                                anchors.fill: parent; radius: width / 2
                                color: app.running || am.containsMouse ? Theme.selection : "transparent"
                                opacity: app.running ? 1 : (am.containsMouse ? 0.6 : 0)
                                Behavior on opacity { NumberAnimation { duration: Theme.ms(140) } }
                            }
                            LIcon { anchors.centerIn: parent; name: app.modelData.icon; size: root.dk.icon; tint: Theme.text
                                scale: am.pressed ? 0.92 : (am.containsMouse && Theme.motion ? 1.08 : 1)
                                Behavior on scale { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } } }
                            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: root.launch(app.modelData.cmd) }
                        }
                    }

                    Rectangle { visible: wl.model.count > 0; width: 1; height: root.dk.tile * 0.7; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }

                    // open windows
                    Repeater {
                        model: wl.model
                        Rectangle {
                            id: wp
                            required property string uuid
                            required property string title
                            required property string appid
                            required property bool isActive
                            width: root.dk.pillWidth; height: root.dk.pillHeight; radius: height / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: isActive ? Theme.selection : (pm.containsMouse ? Theme.surfaceAlt : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
                            opacity: 0
                            Component.onCompleted: opacity = 1
                            Behavior on opacity { NumberAnimation { duration: Theme.ms(180) } }
                            Row {
                                anchors.centerIn: parent; spacing: 8
                                LIcon { name: "panel-top"; size: 16; tint: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, root.dk.pillWidth - 46); elide: Text.ElideRight
                                    text: wp.title !== "" ? wp.title : wp.appid
                                    color: Theme.text; font.family: Theme.serif; font.italic: true; font.pixelSize: 14
                                    renderType: Text.NativeRendering
                                }
                            }
                            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: wl.activate(wp.uuid) }
                        }
                    }
                }
            }
        }
    }
}
