// One installed rice row with its applicable data parts. Expands to one row
// per format the rice ships; each row offers the real variants and applies
// through elto-world applypart (data copies + best-effort activation).
// Plasma desktop themes are listed but not offered for apply: under the
// ElTo shell they style nothing, and the row says so instead of pretending.
import QtQuick

Column {
    id: rice
    property var st: ManagerStyle {}
    property StoreBridge bridge: null
    property var item: ({})
    signal toggled(bool on)
    signal removeRequested()

    property bool open: false
    property var parts: null
    property string feedback: ""

    // [{fmt, label, variants, idx, applicable, note}]
    property var partRows: []

    function loadParts() {
        if (!bridge) return
        bridge.riceParts(item.key, function (o) {
            if (!o.ok) { rice.feedback = o.error || "parts unavailable"; return }
            const p = o.parts || {}
            const rows = []
            const defs = [
                { fmt: "colorscheme", label: "Color scheme", variants: p.colorschemes || [], applicable: true, note: "" },
                { fmt: "aurorae", label: "Window frame (Aurorae)", variants: p.aurorae || [], applicable: true, note: "" },
                { fmt: "wallpaper", label: "Wallpaper", variants: p.wallpapers || [], applicable: true, note: "" },
                { fmt: "desktoptheme", label: "Plasma desktop theme", variants: p.desktopthemes || [], applicable: false,
                  note: "styles Plasma shell components; the ElTo shell draws its own, so applying it changes nothing here" }
            ]
            for (const d of defs)
                if (d.variants.length > 0) rows.push({ fmt: d.fmt, label: d.label, variants: d.variants,
                                                       idx: 0, applicable: d.applicable, note: d.note })
            rice.partRows = rows
            if (rows.length === 0) rice.feedback = "No applicable data parts in this rice."
        })
    }

    width: parent ? parent.width : 600
    spacing: 0

    Rectangle {
        width: parent.width; height: 64; radius: rice.open ? 0 : st.radiusSmall
        color: "#ffffff"; border.width: 1; border.color: st.line

        Column {
            x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 330
            Text { text: rice.item.title || ""; color: st.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
            Text {
                text: "rices  -  v" + (rice.item.version || "?") + "  -  GitHub rice, pinned data subset"
                color: st.muted; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width
            }
        }

        Text {
            x: parent.width - 328; anchors.verticalCenter: parent.verticalCenter
            text: rice.open ? "Parts  -" : "Parts  +"
            color: st.accent; font.pixelSize: 12; font.bold: true
            MouseArea { anchors.fill: parent; onClicked: { rice.open = !rice.open; if (rice.open && rice.parts === null) rice.loadParts() } }
        }

        Rectangle {
            x: parent.width - 262; anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 26; radius: 13
            color: rice.item.enabled ? st.accent : st.line
            Rectangle {
                y: 3; width: 20; height: 20; radius: 10; color: "#ffffff"
                x: rice.item.enabled ? 23 : 3
                Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea { anchors.fill: parent; onClicked: rice.toggled(!rice.item.enabled) }
        }

        Text {
            x: parent.width - 186; anchors.verticalCenter: parent.verticalCenter
            text: "Remove"; color: st.gold; font.pixelSize: 12
            MouseArea { anchors.fill: parent; onClicked: rice.removeRequested() }
        }
    }

    Rectangle {
        visible: rice.open
        width: parent.width
        height: visible ? partsCol.height + 16 : 0
        color: "#fbfcfd"; border.width: 1; border.color: st.line
        radius: st.radiusSmall

        Column {
            id: partsCol
            x: 14; y: 8; width: parent.width - 28; spacing: 6

            Text {
                visible: rice.feedback !== ""
                text: rice.feedback; color: st.gold; font.pixelSize: 11
                width: parent.width; wrapMode: Text.WordWrap
            }

            Repeater {
                model: rice.partRows
                Row {
                    required property var modelData
                    required property int index
                    width: partsCol.width; height: 26; spacing: 8

                    Text {
                        width: 190; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label; color: st.ink; font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.applicable
                        anchors.verticalCenter: parent.verticalCenter
                        text: "<"; color: st.accent; font.pixelSize: 13; font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const rows = rice.partRows.slice()
                                const r = Object.assign({}, rows[index])
                                r.idx = (r.idx - 1 + r.variants.length) % r.variants.length
                                rows[index] = r
                                rice.partRows = rows
                            }
                        }
                    }
                    Text {
                        width: 220; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.applicable ? modelData.variants[modelData.idx] : modelData.note
                        color: modelData.applicable ? st.ink : st.muted
                        font.pixelSize: modelData.applicable ? 12 : 10
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.applicable
                        anchors.verticalCenter: parent.verticalCenter
                        text: ">"; color: st.accent; font.pixelSize: 13; font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const rows = rice.partRows.slice()
                                const r = Object.assign({}, rows[index])
                                r.idx = (r.idx + 1) % r.variants.length
                                rows[index] = r
                                rice.partRows = rows
                            }
                        }
                    }
                    Rectangle {
                        visible: modelData.applicable
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64; height: 22; radius: 11
                        color: applyMa.containsMouse ? st.accentHi : st.accent
                        Text { anchors.centerIn: parent; text: "Apply"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                        MouseArea {
                            id: applyMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                rice.feedback = "applying " + modelData.variants[modelData.idx] + "..."
                                rice.bridge.applyRicePart(rice.item.key, modelData.fmt,
                                    modelData.variants[modelData.idx], function (o) {
                                    rice.feedback = o.ok ? modelData.label + " applied: " + modelData.variants[modelData.idx]
                                        : ("Apply failed safely: " + (o.error || "unknown error"))
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
