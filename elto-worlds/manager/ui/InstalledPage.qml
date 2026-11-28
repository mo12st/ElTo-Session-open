// Installed: the applied world (from elto-world status) plus the store
// registry of imported parts, with enable/disable and remove.
import QtQuick

Item {
    id: page
    property var st: ManagerStyle {}
    property StoreBridge bridge: null

    property string appliedWorld: ""
    property var registry: []

    function reload() {
        if (!bridge) return
        bridge.status(function (o) { if (o.ok) page.appliedWorld = o.world || "" })
        bridge.installed(function (o) { if (o.ok) page.registry = o.items })
    }
    Component.onCompleted: reload()
    Connections {
        target: page.bridge
        function onStatusChanged() { page.reload() }
    }

    Flickable {
        anchors.fill: parent; contentHeight: col.height; clip: true
        Column {
            id: col; x: 16; y: 16; width: page.width - 32; spacing: 8
            Text { text: "APPLIED WORLD"; color: page.st.gold; font.pixelSize: 10; font.letterSpacing: 2 }
            Rectangle {
                width: parent.width; height: 52; radius: page.st.radiusSmall
                color: "#ffffff"; border.width: 1; border.color: page.st.line
                Text {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    text: page.appliedWorld !== "" ? page.appliedWorld : "no world applied yet"
                    color: page.st.ink; font.pixelSize: 15; font.bold: page.appliedWorld !== ""
                }
            }
            Text { text: "IMPORTED PARTS"; color: page.st.gold; font.pixelSize: 10; font.letterSpacing: 2; topPadding: 12 }
            Repeater {
                model: page.registry
                PartRow {
                    st: page.st
                    item: modelData
                    onToggled: function (on) { page.bridge.setEnabled(modelData.key, on, function () { page.reload() }) }
                    onRemoveRequested: page.bridge.remove(modelData.key, function () { page.reload() })
                }
            }
            Text {
                visible: page.registry.length === 0
                text: "No imported parts yet. KDE data items install from Discover."
                color: page.st.muted; font.pixelSize: 12
            }
        }
    }
}
