// CONCEPT / SPIKE widget, not a design. Quickshell.Bluetooth only (BlueZ over D-Bus), no Plasma imports.
// API names checked against quickshell master src/bluetooth/*.hpp; the installed Quickshell version must have the module.
import QtQuick
import Quickshell.Bluetooth

Text {
    id: root

    property color textColor: "#283a32"
    readonly property var adapter: Bluetooth.defaultAdapter

    // Number of connected devices on the default adapter.
    readonly property int connectedCount: {
        if (adapter === null)
            return 0;
        const list = adapter.devices.values;
        let n = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                n++;
        }
        return n;
    }

    color: root.textColor
    font.pixelSize: 20
    text: adapter === null ? "bt n/a"
        : !adapter.enabled ? "bt off"
        : connectedCount > 0 ? "bt " + connectedCount
        : "bt on"

    // Click toggles the adapter power state.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.adapter !== null)
                root.adapter.enabled = !root.adapter.enabled;
        }
    }
}
