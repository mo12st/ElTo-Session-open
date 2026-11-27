// Bluetooth page: BlueZ only. State from Quickshell.Bluetooth (same import Bluetooth.qml
// uses); actions through bluetoothctl (bluez-utils) so pairing, which has no stable QML API
// yet, still works. No applet, no daemon added.
// Condition: with no adapter the page says so; with the adapter off it offers Enable only.
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick

Item {
    id: page
    anchors.fill: parent

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool btOn: hasAdapter && adapter.enabled
    readonly property var devices: hasAdapter ? adapter.devices.values : []

    property bool scanning: false
    property string busyAddr: ""
    property string lastError: ""

    function run(args) {
        lastError = ""
        ctl.command = ["bluetoothctl"].concat(args)
        ctl.running = true
    }

    Process {
        id: ctl
        onRunningChanged: if (!running) page.busyAddr = ""
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.lastError = text.trim() }
        }
    }

    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: page.scanning = false
    }

    Column {
        x: 28; y: 4; width: parent.width - 56; spacing: 10

        Rectangle {
            visible: !page.hasAdapter
            width: parent.width; height: 60; radius: Theme.radiusCard; color: Theme.surfaceAlt
            Text {
                anchors.centerIn: parent
                text: I18n.t("btNoAdapter")
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 14
            }
        }

        ElRow {
            visible: page.hasAdapter
            width: parent.width
            title: I18n.t("bluetooth")
            subtitle: page.btOn ? "" : I18n.t("btOff")
            ElToggle {
                checked: page.btOn
                onToggled: page.run(["power", page.btOn ? "off" : "on"])
            }
            ElButton {
                text: page.scanning ? I18n.t("scanning") : I18n.t("scan")
                busy: page.scanning
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    page.scanning = true
                    scanTimer.restart()
                    page.run(["--timeout", "10", "scan", "on"])
                }
            }
        }

        Text {
            visible: page.hasAdapter && page.devices.length === 0
            text: I18n.t("noDevices")
            color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 14
        }

        Flickable {
            visible: page.hasAdapter
            width: parent.width
            height: Math.min(contentHeight, page.height - 130)
            contentHeight: devCol.height
            clip: true

            Column {
                id: devCol
                width: parent.width
                spacing: 8
                Repeater {
                    model: page.devices
                    ElRow {
                        required property var modelData
                        readonly property var dev: modelData
                        readonly property bool isPaired: dev.paired === true || dev.bonded === true
                        width: devCol.width
                        title: dev.name !== "" ? dev.name : dev.address
                        subtitle: (isPaired ? I18n.t("paired") : "") + (dev.connected ? " · " + I18n.t("connectedTo") : "")
                        Rectangle {
                            visible: dev.connected
                            width: 22; height: 22; radius: 11; color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: "✓"; color: Theme.surface; font.pixelSize: 13; font.bold: true }
                        }
                        ElButton {
                            text: dev.connected ? I18n.t("disconnect") : (isPaired ? I18n.t("connect") : I18n.t("pair"))
                            busy: page.busyAddr === dev.address
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                page.busyAddr = dev.address
                                if (dev.connected) page.run(["disconnect", dev.address])
                                else if (isPaired) page.run(["connect", dev.address])
                                else page.run(["pair", dev.address])
                            }
                        }
                        ElButton {
                            visible: isPaired
                            text: I18n.t("forget")
                            danger: true
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: page.run(["remove", dev.address])
                        }
                    }
                }
            }
        }

        Text {
            visible: page.lastError !== ""
            text: I18n.t("actionFailed") + ": " + page.lastError
            color: Theme.color("rust"); font.family: Theme.sans; font.pixelSize: 13
            width: parent.width; wrapMode: Text.Wrap
        }
    }
}
