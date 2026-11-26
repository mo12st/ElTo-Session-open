// CONCEPT / SPIKE app launcher, UNVERIFIED until a VM run.
// Palette and motion tokens from ElToPalette. Quickshell built-ins only (DesktopEntries, IpcHandler).
// Toggle from a shell: quickshell -p panel-widgets/launcher-spike.qml, then `quickshell ipc call launcher toggle`.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win

    property bool open: false
    property string query: ""

    function toggle() {
        open = !open;
        if (open) {
            query = "";
            search.text = "";
            search.forceActiveFocus();
        }
    }

    anchors {
        left: true
        bottom: true
    }
    margins {
        left: 12
        bottom: 64
    }
    implicitWidth: 380
    implicitHeight: 460
    color: "transparent"
    visible: popup.visible
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            win.toggle();
        }
    }

    ScriptModel {
        id: filtered
        values: {
            const q = win.query.trim().toLowerCase();
            const all = [...DesktopEntries.applications.values].filter(e => !e.noDisplay);
            const hits = q === "" ? all : all.filter(e => e.name.toLowerCase().includes(q));
            return hits.sort((a, b) => a.name.localeCompare(b.name));
        }
    }

    ElToPopup {
        id: popup
        anchors.fill: parent
        open: win.open

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: ElToPalette.cream
            border.width: 1
            border.color: ElToPalette.inactiveBg

            Rectangle {
                id: box
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                height: 40
                radius: 20
                color: ElToPalette.creamDark

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 16
                    color: ElToPalette.text
                    onTextChanged: win.query = text
                    Keys.onEscapePressed: win.open = false
                    Keys.onReturnPressed: {
                        if (list.count > 0) {
                            filtered.values[Math.max(0, list.currentIndex)].execute();
                            win.open = false;
                        }
                    }
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                }
                Text {
                    anchors.fill: search
                    verticalAlignment: Text.AlignVCenter
                    text: "Search apps"
                    font.pixelSize: 16
                    color: ElToPalette.inactiveFg
                    visible: search.text === ""
                }
            }

            ListView {
                id: list
                anchors {
                    left: parent.left
                    right: parent.right
                    top: box.bottom
                    bottom: parent.bottom
                    margins: 14
                }
                clip: true
                spacing: 4
                model: filtered
                currentIndex: 0
                highlightMoveDuration: ElToPalette.hoverMs

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 40
                    radius: 10
                    color: area.containsMouse || ListView.isCurrentItem ? ElToPalette.lightGreen : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: ElToPalette.hoverMs
                            easing.type: ElToPalette.easing
                        }
                    }

                    IconImage {
                        id: icon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 24
                        source: Quickshell.iconPath(row.modelData.icon, true)
                    }
                    Text {
                        anchors.left: icon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 15
                        color: ElToPalette.text
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            row.modelData.execute();
                            win.open = false;
                        }
                    }
                }
            }
        }
    }
}
