// Customize: what the current overlay carries (sections and options from
// elto-world status) and a reset to world defaults. Per-part source mixing
// arrives with the mix editor; this page stays honest about what exists.
import QtQuick

Item {
    id: page
    property var st: ManagerStyle {}
    property StoreBridge bridge: null

    property string appliedWorld: ""
    property var sections: []
    property var optionKeys: []
    property string notice: ""

    function reload() {
        if (!bridge) return
        bridge.status(function (o) {
            if (!o.ok) { page.notice = o.error || "status unavailable"; return }
            page.appliedWorld = o.world || ""
            page.sections = o.sections || []
            page.optionKeys = Object.keys(o.options || {})
            page.notice = ""
        })
    }
    Component.onCompleted: reload()
    Connections {
        target: page.bridge
        function onStatusChanged() { page.reload() }
    }

    Column {
        x: 16; y: 16; width: page.width - 32; spacing: 8
        Text {
            text: page.appliedWorld !== "" ? "Current world: " + page.appliedWorld : "No world applied"
            color: page.st.ink; font.pixelSize: 18; font.bold: true
        }
        Text {
            text: "Themed sections: " + (page.sections.length ? page.sections.join(", ") : "none")
            color: page.st.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width
        }
        Text {
            text: "Options: " + (page.optionKeys.length ? page.optionKeys.join(", ") : "none")
            color: page.st.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width
        }
        Rectangle {
            width: 220; height: 36; radius: 18; color: page.st.paper2
            Text { anchors.centerIn: parent; text: "Reset to world defaults"; color: page.st.ink; font.pixelSize: 13 }
            MouseArea {
                anchors.fill: parent
                onClicked: page.bridge.reset(function (o) { page.notice = o.ok ? "Defaults restored." : (o.error || "reset failed") })
            }
        }
        Text { visible: page.notice !== ""; text: page.notice; color: page.st.gold; font.pixelSize: 12 }
    }
}
