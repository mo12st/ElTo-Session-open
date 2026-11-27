// ElTo Control: one window, one style, six pages. Deep link: `elto-control <page>`
// (wrapper exports ELTO_CONTROL_PAGE; unknown pages fall back to appearance).
// The themes page embeds the implementer's panel-widgets/ThemesPage.qml whole.
// Pages load lazily: a broken page shows an error card and cannot break the rest.
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: app

    readonly property var pages: [
        { id: "appearance", icon: "palette",   iconDir: "../icons/lucide" },
        { id: "themes",     icon: "panel-top", iconDir: "../icons/lucide" },
        { id: "sound",      icon: "volume-2",  iconDir: "../icons/lucide" },
        { id: "network",    icon: "wifi",      iconDir: "../icons/lucide" },
        { id: "bluetooth",  icon: "bluetooth", iconDir: "icons" },
        { id: "power",      icon: "power",     iconDir: "icons" },
        { id: "about",      icon: "info",      iconDir: "icons" }
    ]
    readonly property var validIds: ["appearance", "themes", "sound", "network", "bluetooth", "power", "about"]

    property string current: {
        var wanted = Quickshell.env("ELTO_CONTROL_PAGE")
        return validIds.indexOf(wanted) >= 0 ? wanted : "appearance"
    }

    // ---- world bundle import (theme-tool install-bundle -> elto-world install, PR #40)
    property string bundleStatus: ""
    property bool bundleStatusIsError: false
    function installBundle(path) {
        if (!path || bundleRunner.running) return
        bundleStatus = ""
        bundleStatusIsError = false
        bundleRunner.command = ["python3", Quickshell.shellPath("theme-tool.py"), "install-bundle", path]
        bundleRunner.running = true
    }

    FloatingWindow {
        id: win
        title: I18n.t("appTitle")
        implicitWidth: 1180
        implicitHeight: 700
        minimumSize: Qt.size(900, 600)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusWindow
            color: Theme.surface
            clip: true
            border.width: 1
            border.color: Theme.divider
            LayoutMirroring.enabled: I18n.rtl
            LayoutMirroring.childrenInherit: true

            // ---------- sidebar
            Rectangle {
                id: side
                width: 200
                height: parent.height
                color: Theme.surfaceAlt

                Text {
                    x: 20; y: 24
                    text: I18n.t("appTitle")
                    color: Theme.text
                    font.family: Theme.serif
                    font.pixelSize: 24
                    renderType: Text.NativeRendering
                }

                // language switch (writes control.json, every string rebinds live)
                Row {
                    x: 20; y: 64; spacing: 6
                    Repeater {
                        model: [{ code: "en", label: "EN" }, { code: "ar", label: "ع" }]
                        Rectangle {
                            required property var modelData
                            readonly property bool cur: I18n.lang === modelData.code
                            width: 40; height: 28; radius: 14
                            color: cur ? Theme.selection : "transparent"
                            border.width: cur ? 0 : 1
                            border.color: Theme.divider
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Theme.text
                                font.family: Theme.sans
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.set("language", modelData.code)
                            }
                        }
                    }
                }

                Column {
                    x: 12; y: 110; spacing: 4
                    width: side.width - 24
                    Repeater {
                        model: app.pages
                        Rectangle {
                            required property var modelData
                            readonly property bool cur: app.current === modelData.id
                            width: parent.width
                            height: 40
                            radius: 20
                            color: cur ? Theme.selection : "transparent"
                            Row {
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                ElIcon {
                                    name: modelData.icon
                                    dir: modelData.iconDir
                                    size: 18
                                    tint: Theme.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: I18n.t(modelData.id)
                                    color: Theme.text
                                    font.family: Theme.sans
                                    font.pixelSize: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: app.current = modelData.id
                            }
                        }
                    }
                }
            }

            // ---------- header (the themes page draws its own, pixel-identical to Customize)
            Text {
                visible: app.current !== "themes"
                x: side.width + 28; y: 22
                text: I18n.t(app.current)
                color: Theme.text
                font.family: Theme.serif
                font.pixelSize: 38
                renderType: Text.NativeRendering
            }

            // ---------- page content (lazy; error degrades to a card, never breaks the app)
            Loader {
                id: pageLoader
                x: side.width
                y: 84
                width: parent.width - side.width
                height: parent.height - 84
                source: app.current === "themes" ? "" : app.current.charAt(0).toUpperCase() + app.current.slice(1) + "Page.qml"
                asynchronous: false
            }

            // Themes page: the implementer's own component (panel-widgets/ThemesPage.qml,
            // VM-proven in Customize), embedded whole. It draws its own header at the same
            // metrics as ours. Its UI strings are English-only for now; localizing them means
            // editing the implementer's file, tracked as a follow-up.
            ThemesPage {
                visible: app.current === "themes"
                x: side.width
                y: 0
                width: parent.width - side.width
                height: parent.height
            }

            // ---- import a world bundle (.elworld) from the themes page.
            // Runs theme-tool install-bundle, which calls elto-world install: verify + staged
            // unpack, never overwrites, does NOT apply the world. Errors show inline (condition 3).
            Process {
                id: bundleRunner
                stdout: StdioCollector {
                    onStreamFinished: {
                        var o, errs
                        try {
                            o = JSON.parse(text)
                            if (o.ok) {
                                app.bundleStatusIsError = false
                                app.bundleStatus = I18n.t("bundleInstalled") + ": " + (o.label || o.world || o.installed || "")
                            } else {
                                app.bundleStatusIsError = true
                                errs = o.errors || [o.error || "?"]
                                app.bundleStatus = I18n.t("bundleFailed") + ": " + errs.join("; ")
                            }
                        } catch (e) {
                            app.bundleStatusIsError = true
                            app.bundleStatus = I18n.t("bundleFailed") + ": " + text.trim().substring(0, 200)
                        }
                    }
                }
                stderr: StdioCollector {
                    onStreamFinished: {
                        if (text.trim() !== "") {
                            app.bundleStatusIsError = true
                            app.bundleStatus = I18n.t("bundleFailed") + ": " + text.trim().substring(0, 200)
                        }
                    }
                }
            }

            ElButton {
                visible: app.current === "themes"
                x: side.width + 28
                y: parent.height - 48
                text: I18n.t("importBundle")
                onClicked: bundlePanel.visible = !bundlePanel.visible
            }

            Rectangle {
                id: bundlePanel
                visible: false
                z: 20
                x: side.width + 28
                y: parent.height - 48 - 116
                width: 540
                height: 108
                radius: Theme.radiusCard
                color: Theme.surface
                border.width: 1
                border.color: Theme.divider

                Rectangle {
                    x: 14; y: 12
                    width: parent.width - 28 - 118
                    height: 36
                    radius: 18
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.divider
                    clip: true
                    TextInput {
                        id: bundlePath
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.sans
                        font.pixelSize: 13
                        color: Theme.text
                        clip: true
                        onAccepted: app.installBundle(text)
                        Text {
                            visible: parent.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("bundlePathHint")
                            color: Theme.disabled
                            font.family: Theme.sans
                            font.pixelSize: 13
                        }
                    }
                }
                ElButton {
                    x: parent.width - 14 - 104
                    y: 12
                    width: 104
                    text: bundleRunner.running ? I18n.t("bundleInstalling") : I18n.t("bundleInstall")
                    busy: bundleRunner.running
                    onClicked: app.installBundle(bundlePath.text)
                }
                Text {
                    x: 14; y: 58
                    width: parent.width - 28
                    text: app.bundleStatus
                    visible: app.bundleStatus !== ""
                    color: app.bundleStatusIsError ? Theme.color("rust") : Theme.textMuted
                    font.family: Theme.sans
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: pageLoader.status === Loader.Error
                x: side.width + 28; y: 120
                width: parent.width - side.width - 56
                height: 60
                radius: Theme.radiusCard
                color: Theme.surfaceAlt
                Text {
                    anchors.centerIn: parent
                    text: I18n.t("pageError")
                    color: Theme.textMuted
                    font.family: Theme.sans
                    font.pixelSize: 14
                }
            }
        }
    }
}
