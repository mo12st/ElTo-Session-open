// ElTo Control: one window, one style, six pages. Deep link: `elto-control <page>`
// (wrapper exports ELTO_CONTROL_PAGE; unknown pages fall back to appearance).
// Pages load lazily: a broken page shows an error card and cannot break the rest.
import Quickshell
import QtQuick
import "../panel-widgets"

ShellRoot {
    id: app

    readonly property var pages: [
        { id: "appearance", icon: "palette",   iconDir: "../icons/lucide" },
        { id: "sound",      icon: "volume-2",  iconDir: "../icons/lucide" },
        { id: "network",    icon: "wifi",      iconDir: "../icons/lucide" },
        { id: "bluetooth",  icon: "bluetooth", iconDir: "icons" },
        { id: "power",      icon: "power",     iconDir: "icons" },
        { id: "about",      icon: "info",      iconDir: "icons" }
    ]
    readonly property var validIds: ["appearance", "sound", "network", "bluetooth", "power", "about"]

    property string current: {
        var wanted = Quickshell.env("ELTO_CONTROL_PAGE")
        return validIds.indexOf(wanted) >= 0 ? wanted : "appearance"
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

            // ---------- header
            Text {
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
                source: app.current.charAt(0).toUpperCase() + app.current.slice(1) + "Page.qml"
                asynchronous: false
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
