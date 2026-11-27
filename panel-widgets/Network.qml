// CONCEPT / SPIKE widget, not a design. Quickshell.Networking only (NetworkManager backend), no Plasma imports.
// API names checked against quickshell master src/network/*.hpp; the installed Quickshell version must have the module.
import QtQuick
import Quickshell.Networking

Text {
    id: root

    property color textColor: "#283a32"
    property int pixelSize: 20

    // First connected device (wifi or wired), or null.
    readonly property var active: {
        const list = Networking.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i];
        }
        return null;
    }

    color: root.textColor
    font.pixelSize: root.pixelSize
    text: Networking.backend === NetworkBackendType.None ? "net n/a"
        : active === null ? "net off"
        : (active.type === DeviceType.Wifi ? "wifi " : "eth ") + active.name
}
