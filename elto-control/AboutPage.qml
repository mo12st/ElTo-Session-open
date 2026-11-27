// About page: static system identity from files every Linux has (/etc/os-release, uname),
// the active World from the shell Theme, and the way out to ElTo Guardian.
// Guardian is a separate component (not installed yet): the button reports that clearly
// instead of pretending (binding condition 3). No daemon added.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    anchors.fill: parent

    property string distro: ""
    property string kernel: ""
    property string guardianStatus: ""

    FileView {
        path: "/etc/os-release"
        blockLoading: true
        onLoaded: {
            var lines = text().split("\n")
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("PRETTY_NAME=") === 0) {
                    page.distro = lines[i].substring(12).replace(/^"|"$/g, "")
                    break
                }
            }
        }
    }

    Process {
        id: unameProc
        command: ["uname", "-r"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.kernel = text.trim() }
    }

    Process {
        id: guardianCheck
        command: ["sh", "-c", "command -v elto-guardian"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim()
                if (p === "") page.guardianStatus = I18n.t("guardianMissing")
                else { page.guardianStatus = ""; guardianRun.command = [p]; guardianRun.running = true }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") page.guardianStatus = I18n.t("guardianMissing") }
        }
    }
    Process { id: guardianRun }

    Column {
        x: 28; y: 4; width: parent.width - 56; spacing: 10

        Text {
            text: I18n.t("system")
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22
            renderType: Text.NativeRendering
        }

        ElRow {
            width: parent.width
            title: I18n.t("appTitle")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("world") + ": " + (Theme.name !== "" ? Theme.name : "-")
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 13
            }
        }
        ElRow {
            width: parent.width
            title: I18n.t("distro")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.distro !== "" ? page.distro : "-"
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 13
            }
        }
        ElRow {
            width: parent.width
            title: I18n.t("kernel")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.kernel !== "" ? page.kernel : "-"
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 13
            }
        }
        ElRow {
            width: parent.width
            title: I18n.t("language")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.lang === "ar" ? "العربية" : "English"
                color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 13
            }
        }

        Text {
            y: 8
            text: I18n.t("guardian")
            color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 22
            renderType: Text.NativeRendering
        }

        ElRow {
            width: parent.width
            title: I18n.t("guardian")
            subtitle: I18n.t("guardianDesc")
            ElButton {
                text: I18n.t("openGuardian")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: { page.guardianStatus = ""; guardianCheck.running = true }
            }
        }
        Text {
            visible: page.guardianStatus !== ""
            text: page.guardianStatus
            color: Theme.textMuted; font.family: Theme.sans; font.pixelSize: 13
        }
    }
}
