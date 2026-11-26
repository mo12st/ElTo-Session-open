// CONCEPT-SPIKE, not a design. Quickshell reads the elto-windowlist JSON-lines stream and shows one button per window.
// Click a button -> "activate <uuid>" is written to the helper's stdin.
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root
    property var wins: ({})        // uuid -> {title, appid, flags}
    property var order: []         // uuids in arrival order
    property int rev: 0

    function handle(line) {
        let m;
        try { m = JSON.parse(line); } catch (e) { console.log("TASKBAR bad json: " + line); return; }
        if (m.event === "add") {
            wins[m.uuid] = { title: "", appid: "", flags: 0 };
            order.push(m.uuid);
        } else if (m.event === "close") {
            delete wins[m.uuid];
            order = order.filter(u => u !== m.uuid);
        } else if (wins[m.uuid]) {
            if (m.event === "title") wins[m.uuid].title = m.title;
            else if (m.event === "appid") wins[m.uuid].appid = m.appid;
            else if (m.event === "state") wins[m.uuid].flags = m.flags;
        }
        rev++;
        console.log("TASKBAR " + m.event + " now=" + order.length);
    }

    function titleOf(u) { const w = wins[u]; return w ? (w.title !== "" ? w.title : w.appid) : ""; }
    function activeOf(u) { const w = wins[u]; return w ? (w.flags & 1) !== 0 : false; }

    Process {
        id: wl
        running: true
        command: ["/tmp/elto-windowlist"]
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.handle(data) }
        stderr: SplitParser { onRead: data => console.log("TASKBAR helper stderr: " + data) }
    }

    PanelWindow {
        anchors { left: true; right: true; bottom: true }
        implicitHeight: 56
        color: "#f6f1e4"
        Text {
            anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter
            text: "CONCEPT-SPIKE  windows: " + (root.rev >= 0 ? root.order.length : 0)
            color: "#a05040"; font.pixelSize: 16
        }
        Row {
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                model: root.rev >= 0 ? root.order : []
                delegate: Rectangle {
                    required property string modelData
                    width: 180; height: 36; radius: 18
                    color: (root.rev >= 0 && root.activeOf(modelData)) ? "#cfe3d4" : "#efe9d8"
                    border.color: "#283a32"
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: root.rev >= 0 ? root.titleOf(modelData) : ""
                        color: "#283a32"; font.pixelSize: 15
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { wl.write("activate " + modelData + "\n"); console.log("TASKBAR click " + modelData); }
                    }
                }
            }
        }
    }
}
