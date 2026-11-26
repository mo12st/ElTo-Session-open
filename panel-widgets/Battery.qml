// CONCEPT / SPIKE widget, not a design. Quickshell.Services.UPower only, no Plasma imports.
// Hidden when the machine has no battery (for example the CI/VM rig).
import QtQuick
import Quickshell.Services.UPower

Text {
    id: root

    property color textColor: "#283a32"
    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isPresent
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging

    visible: present
    color: root.textColor
    font.pixelSize: 20
    // UPowerDevice.percentage is a 0..1 fraction in Quickshell.
    text: present ? "bat " + Math.round(device.percentage * 100) + "%" + (charging ? " +" : "") : ""
}
