// Updates: re-list the KDE categories of installed parts and compare the
// pinned version. A changed upstream version is an update candidate;
// applying it is a fresh import (a saved mix is never auto-rewritten).
import QtQuick

Item {
    id: page
    property var st: ManagerStyle {}
    property StoreBridge bridge: null

    property var rows: []      // {title, oldV, newV, entry}
    property string notice: ""

    function reload() {
        rows = []; notice = ""
        if (!bridge) return
        bridge.installed(function (o) {
            if (!o.ok) { page.notice = o.error || "registry unavailable"; return }
            const kdeItems = o.items.filter(i => i.source === "kde")
            if (kdeItems.length === 0) { page.notice = "Nothing to check: no KDE imports installed." ; return }
            const cats = [...new Set(kdeItems.map(i => i.category))]
            let listings = []
            let left = cats.length
            cats.forEach(function (c) {
                page.bridge.kde(c, function (lo) {
                    left--
                    if (lo.ok) listings = listings.concat(lo.items)
                    if (left === 0) {
                        const out = []
                        kdeItems.forEach(function (inst) {
                            const fresh = listings.find(l => String(l.ocsId) === String(inst.key.split("-")[1]))
                            if (fresh && fresh.version && fresh.version !== inst.version)
                                out.push({ title: inst.title, oldV: inst.version, newV: fresh.version, entry: fresh })
                        })
                        page.rows = out
                        page.notice = out.length === 0 ? "Everything is up to date." : ""
                    }
                })
            })
        })
    }
    Component.onCompleted: reload()

    Column {
        x: 16; y: 16; width: page.width - 32; spacing: 8
        Text { visible: page.notice !== ""; text: page.notice; color: page.st.muted; font.pixelSize: 12 }
        Repeater {
            model: page.rows
            Rectangle {
                required property var modelData
                width: parent.width; height: 64; radius: page.st.radiusSmall
                color: "#ffffff"; border.width: 1; border.color: page.st.line
                Column {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    Text { text: modelData.title; color: page.st.ink; font.pixelSize: 14; font.bold: true }
                    Text { text: "v" + modelData.oldV + "  ->  v" + modelData.newV; color: page.st.accent; font.pixelSize: 11 }
                }
                Rectangle {
                    x: parent.width - 106; anchors.verticalCenter: parent.verticalCenter
                    width: 92; height: 28; radius: 14; color: page.st.paper2
                    Text { anchors.centerIn: parent; text: "Update"; color: page.st.ink; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: { page.bridge.installKde(modelData.entry); page.reload() } }
                }
            }
        }
    }
}
