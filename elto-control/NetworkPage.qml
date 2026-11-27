// Network page: NetworkManager only. State from Quickshell.Networking (same import
// Network.qml uses); actions through nmcli (part of the networkmanager package, always
// present). No applet, no daemon added.
// Condition: when NetworkManager is not running, the page says so instead of faking controls.
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Item {
    id: page
    anchors.fill: parent

    readonly property bool backendUp: Networking.backend !== NetworkBackendType.None

    property bool wifiOn: true
    property var networks: []
    property string expandedSsid: ""
    property string connectingSsid: ""
    property string lastError: ""
    property string password: ""

    function refresh() {
        listProc.running = true
    }

    // nmcli -t escapes ':' and '\' with a backslash; split on unescaped ':' only.
    function splitEscaped(line) {
        var fields = [], cur = ""
        for (var i = 0; i < line.length; i++) {
            var c = line.charAt(i)
            if (c === "\\" && i + 1 < line.length) { cur += line.charAt(i + 1); i++ }
            else if (c === ":") { fields.push(cur); cur = "" }
            else cur += c
        }
        fields.push(cur)
        return fields
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.wifiOn = text.trim() === "enabled" }
    }

    Process {
        id: radioSet
        onRunningChanged: if (!running) radioProc.running = true
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onRunningChanged: if (!running) rescanTimer.start()
    }
    Timer { id: rescanTimer; interval: 1200; onTriggered: page.refresh() }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {}, out = [], connected = ""
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line === "") continue
                    var f = page.splitEscaped(line)
                    var ssid = f[0] || ""
                    if (ssid === "" || seen[ssid]) continue
                    seen[ssid] = true
                    var inUse = (f[3] || "").indexOf("*") >= 0
                    if (inUse) connected = ssid
                    out.push({ ssid: ssid, signal: parseInt(f[1] || "0"), security: f[2] || "", inUse: inUse })
                }
                out.sort(function (a, b) { return (b.inUse - a.inUse) || (b.signal - a.signal) })
                page.networks = out
                page.connectedSsid = connected
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.lastError = text.trim() }
        }
    }

    property string connectedSsid: ""

    Process {
        id: connProc
        onRunningChanged: {
            if (!running) {
                page.connectingSsid = ""
                page.password = ""
                page.refresh()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.lastError = text.trim() }
        }
    }

    function connectTo(ssid, secured) {
        lastError = ""
        connectingSsid = ssid
        if (secured)
            connProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        else
            connProc.command = ["nmcli", "device", "wifi", "connect", ssid]
        connProc.running = true
    }

    function disconnectCurrent() {
        lastError = ""
        connProc.command = ["nmcli", "connection", "down", "id", connectedSsid]
        connProc.running = true
    }

    Component.onCompleted: refresh()

    Column {
        x: 28; y: 4; width: parent.width - 56; spacing: 10

        Rectangle {
            visible: !page.backendUp
            width: parent.width; height: 60; radius: Theme.radiusCard; color: Theme.surfaceAlt
            Text {
                anchors.centerIn: parent
                text: I18n.t("networkUnavailable")
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 14
            }
        }

        ElRow {
            visible: page.backendUp
            width: parent.width
            title: I18n.t("wifi")
            subtitle: page.connectedSsid !== "" ? I18n.t("connectedTo") + " " + page.connectedSsid : I18n.t("notConnected")
            ElToggle {
                checked: page.wifiOn
                onToggled: {
                    radioSet.command = ["nmcli", "radio", "wifi", page.wifiOn ? "off" : "on"]
                    radioSet.running = true
                }
            }
            ElButton {
                text: I18n.t("rescan")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: { page.lastError = ""; rescanProc.running = true }
            }
        }

        Text {
            visible: page.backendUp && page.wifiOn && page.networks.length === 0
            text: I18n.t("noNetworks")
            color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 14
        }

        Flickable {
            visible: page.backendUp && page.wifiOn
            width: parent.width
            height: Math.min(contentHeight, page.height - 120)
            contentHeight: netCol.height
            clip: true

            Column {
                id: netCol
                width: parent.width
                spacing: 8
                Repeater {
                    model: page.networks
                    Column {
                        required property var modelData
                        readonly property var net: modelData
                        readonly property bool expanded: page.expandedSsid === net.ssid
                        readonly property bool secured: net.security !== "" && net.security !== "--"
                        width: netCol.width
                        spacing: 8

                        ElRow {
                            width: parent.width
                            title: net.ssid
                            subtitle: (net.secured ? I18n.t("secured") : I18n.t("openNetwork")) + " · " + net.signal + "%"
                            Rectangle {
                                visible: net.inUse
                                width: 22; height: 22; radius: 11; color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                                Text { anchors.centerIn: parent; text: "✓"; color: Theme.surface; font.pixelSize: 13; font.bold: true }
                            }
                            ElButton {
                                text: net.inUse ? I18n.t("disconnect") : (page.connectingSsid === net.ssid ? I18n.t("connecting") : I18n.t("connect"))
                                busy: page.connectingSsid === net.ssid
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    if (net.inUse) page.disconnectCurrent()
                                    else if (net.secured) page.expandedSsid = expanded ? "" : net.ssid
                                    else page.connectTo(net.ssid, false)
                                }
                            }
                        }

                        // password row for secured networks
                        Rectangle {
                            visible: expanded && !net.inUse
                            width: parent.width; height: 52; radius: Theme.radiusCard; color: Theme.surfaceAlt
                            Rectangle {
                                x: 16; anchors.verticalCenter: parent.verticalCenter
                                width: 260; height: 34; radius: 17; color: Theme.surface
                                border.width: 1; border.color: Theme.divider
                                clip: true
                                TextInput {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14; anchors.rightMargin: 14
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: page.password
                                    onTextChanged: page.password = text
                                    echoMode: TextInput.Password
                                    color: Theme.text
                                    font.family: Theme.sans; font.pixelSize: 14
                                    Keys.onReturnPressed: page.connectTo(net.ssid, true)
                                    Text {
                                        visible: parent.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: I18n.t("password")
                                        color: Theme.disabled; font.family: Theme.sans; font.pixelSize: 14
                                    }
                                }
                            }
                            ElButton {
                                anchors.right: parent.right; anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.connectingSsid === net.ssid ? I18n.t("connecting") : I18n.t("connect")
                                busy: page.connectingSsid === net.ssid
                                onClicked: page.connectTo(net.ssid, true)
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: page.lastError !== ""
            text: I18n.t("connectFailed") + ": " + page.lastError
            color: Theme.color("rust"); font.family: Theme.sans; font.pixelSize: 13
            width: parent.width; wrapMode: Text.Wrap
        }
    }
}
