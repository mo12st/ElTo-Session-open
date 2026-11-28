// One installed KDE import row with its applicable data parts. Expands to
// one row per format the import ships; each row offers the real variants
// and applies through elto-world applypart (data copies + best-effort
// activation). Formats whose effect is conditional carry the backend's
// honest note; GRUB themes get no Apply at all (system path, helper still
// pending) and the row says why instead of pretending.
import QtQuick

Column {
    id: kde
    property var st: ManagerStyle {}
    property StoreBridge bridge: null
    property var item: ({})
    signal toggled(bool on)
    signal removeRequested()

    property bool open: false
    property var parts: null
    property string feedback: ""

    // [{fmt, label, variants, idx, note}]
    property var partRows: []

    readonly property var labels: ({
        colorscheme: "Color scheme",
        aurorae: "Window frame (Aurorae)",
        wallpaper: "Wallpaper",
        cursor: "Mouse cursor",
        icons: "Icon theme",
        sounds: "Sound theme",
        kvantum: "Kvantum (app style)"
    })

    function loadParts() {
        if (!bridge) return
        bridge.kdeParts(item.key, item.category || "", function (o) {
            if (!o.ok) { kde.feedback = o.error || "parts unavailable"; return }
            const p = o.parts || {}
            const notes = o.notes || {}
            const rows = []
            for (const fmt in p)
                if ((p[fmt] || []).length > 0)
                    rows.push({ fmt: fmt, label: kde.labels[fmt] || fmt, variants: p[fmt],
                                idx: 0, note: notes[fmt] || "" })
            if (kde.item.category === "boot-menu")
                rows.push({ fmt: "", label: "GRUB menu theme", variants: [], idx: 0,
                            note: "installs into /boot, a system path - apply needs the system helper, which is still pending" })
            kde.partRows = rows
            if (rows.length === 0)
                kde.feedback = "No safely apply-able parts: this item ships QML or scripts, which the data-only rule leaves unapplied. It stays installed; its KDE Store page has manual options."
        })
    }

    width: parent ? parent.width : 600
    spacing: 0

    Rectangle {
        width: parent.width; height: 64; radius: kde.open ? 0 : st.radiusSmall
        color: "#ffffff"; border.width: 1; border.color: st.line

        Column {
            x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 330
            Text { text: kde.item.title || ""; color: st.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
            Text {
                text: (kde.item.category || "") + "  -  v" + (kde.item.version || "?") + "  -  KDE Store, converted data-only"
                color: st.muted; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width
            }
        }

        Text {
            x: parent.width - 328; anchors.verticalCenter: parent.verticalCenter
            text: kde.open ? "Parts  -" : "Parts  +"
            color: st.accent; font.pixelSize: 12; font.bold: true
            MouseArea { anchors.fill: parent; onClicked: { kde.open = !kde.open; if (kde.open && kde.parts === null) kde.loadParts() } }
        }

        Rectangle {
            x: parent.width - 262; anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 26; radius: 13
            color: kde.item.enabled ? st.accent : st.line
            Rectangle {
                y: 3; width: 20; height: 20; radius: 10; color: "#ffffff"
                x: kde.item.enabled ? 23 : 3
                Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea { anchors.fill: parent; onClicked: kde.toggled(!kde.item.enabled) }
        }

        Text {
            x: parent.width - 186; anchors.verticalCenter: parent.verticalCenter
            text: "Remove"; color: st.gold; font.pixelSize: 12
            MouseArea { anchors.fill: parent; onClicked: kde.removeRequested() }
        }
    }

    Rectangle {
        visible: kde.open
        width: parent.width
        height: visible ? partsCol.height + 16 : 0
        color: "#fbfcfd"; border.width: 1; border.color: st.line
        radius: st.radiusSmall

        Column {
            id: partsCol
            x: 14; y: 8; width: parent.width - 28; spacing: 6

            Text {
                visible: kde.feedback !== ""
                text: kde.feedback; color: st.gold; font.pixelSize: 11
                width: parent.width; wrapMode: Text.WordWrap
            }

            Repeater {
                model: kde.partRows
                Column {
                    required property var modelData
                    required property int index
                    width: partsCol.width; spacing: 0

                    Row {
                        width: parent.width; height: 26; spacing: 8

                        Text {
                            width: 190; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label; color: st.ink; font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: modelData.variants.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "<"; color: st.accent; font.pixelSize: 13; font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    const rows = kde.partRows.slice()
                                    const r = Object.assign({}, rows[index])
                                    r.idx = (r.idx - 1 + r.variants.length) % r.variants.length
                                    rows[index] = r
                                    kde.partRows = rows
                                }
                            }
                        }
                        Text {
                            width: 220; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.variants.length > 0 ? modelData.variants[modelData.idx] : ""
                            color: st.ink; font.pixelSize: 12; elide: Text.ElideRight
                        }
                        Text {
                            visible: modelData.variants.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: ">"; color: st.accent; font.pixelSize: 13; font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    const rows = kde.partRows.slice()
                                    const r = Object.assign({}, rows[index])
                                    r.idx = (r.idx + 1) % r.variants.length
                                    rows[index] = r
                                    kde.partRows = rows
                                }
                            }
                        }
                        Rectangle {
                            visible: modelData.variants.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64; height: 22; radius: 11
                            color: applyMa.containsMouse ? st.accentHi : st.accent
                            Text { anchors.centerIn: parent; text: "Apply"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                            MouseArea {
                                id: applyMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    kde.feedback = "applying " + modelData.variants[modelData.idx] + "..."
                                    kde.bridge.applyKdePart(kde.item.key, modelData.fmt,
                                        modelData.variants[modelData.idx], function (o) {
                                        kde.feedback = o.ok ? modelData.label + " applied: " + modelData.variants[modelData.idx]
                                            : ("Apply failed safely: " + (o.error || "unknown error"))
                                    })
                                }
                            }
                        }
                    }
                    Text {
                        visible: modelData.note !== ""
                        text: modelData.note
                        color: st.muted; font.pixelSize: 10
                        width: parent.width; wrapMode: Text.WordWrap
                        bottomPadding: 4
                    }
                }
            }
        }
    }
}
