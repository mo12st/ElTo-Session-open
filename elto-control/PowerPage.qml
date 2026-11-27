// Power and session page: UPower for battery state (same import Battery.qml uses),
// logind (loginctl / systemctl, already the session's init) for actions.
// Destructive actions need a second click to confirm. No daemon added.
// Condition: on a machine with no battery, the battery row says so instead of faking one.
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Item {
    id: page
    anchors.fill: parent

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isPresent
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    // "" or the action key awaiting confirmation
    property string pending: ""
    property string lastError: ""

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: page.pending = ""
    }

    Process {
        id: act
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.lastError = text.trim() }
        }
    }

    // actions: [key, i18n key, command, destructive]
    readonly property var actions: [
        { key: "lock",     cmd: ["loginctl", "lock-session"],                        danger: false },
        { key: "sleep",    cmd: ["systemctl", "suspend"],                            danger: false },
        { key: "restart",  cmd: ["systemctl", "reboot"],                             danger: true },
        { key: "powerOff", cmd: ["systemctl", "poweroff"],                           danger: true },
        { key: "logOut",   cmd: ["loginctl", "terminate-session", Quickshell.env("XDG_SESSION_ID") || "self"], danger: true }
    ]

    function trigger(a) {
        if (a.danger && pending !== a.key) {
            pending = a.key
            confirmTimer.restart()
            return
        }
        pending = ""
        lastError = ""
        act.command = a.cmd
        act.running = true
    }

    Column {
        x: 28; y: 4; width: parent.width - 56; spacing: 10

        Text {
            text: I18n.t("battery")
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22
            renderType: Text.NativeRendering
        }

        Rectangle {
            visible: !page.hasBattery
            width: parent.width; height: 52; radius: Theme.radiusCard; color: Theme.surfaceAlt
            Text {
                anchors.centerIn: parent
                text: I18n.t("noBattery")
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 14
            }
        }

        ElRow {
            visible: page.hasBattery
            width: parent.width
            title: I18n.t("battery")
            subtitle: page.charging ? I18n.t("charging") : I18n.t("discharging")
            Item {
                width: 160; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: 11; color: Theme.divider }
                Rectangle {
                    y: 0; height: parent.height; radius: 11; color: Theme.color("midGreen")
                    width: page.hasBattery ? parent.width * page.battery.percentage : 0
                }
                Text {
                    anchors.centerIn: parent
                    text: page.hasBattery ? Math.round(page.battery.percentage * 100) + "%" : ""
                    color: Theme.text; font.family: Theme.sans; font.pixelSize: 12
                }
            }
        }

        Text {
            y: 8
            text: I18n.t("session")
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22
            renderType: Text.NativeRendering
        }

        Repeater {
            model: page.actions
            ElRow {
                required property var modelData
                readonly property var a: modelData
                width: parent.width
                title: I18n.t(a.key)
                ElButton {
                    text: page.pending === a.key ? I18n.t("confirm") : I18n.t(a.key)
                    danger: a.danger
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: page.trigger(a)
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
