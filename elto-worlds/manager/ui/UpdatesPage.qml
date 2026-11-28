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
        let worldRows = []
        let kdeRows = []
        let pending = 1
        let kdePending = 0
        function finish() {
            page.rows = worldRows.concat(kdeRows)
            page.notice = page.rows.length === 0 ? "Everything is up to date." : ""
        }
        bridge.worldUpdates(function (o) {
            if (o.ok) worldRows = (o.worlds || []).map(r => ({ title: r.title, oldV: r.oldV, newV: r.newV, worldId: r.id }))
            pending--
            if (pending === 0 && kdePending === 0) finish()
        })
        bridge.installed(function (o) {
            if (!o.ok) { page.notice = o.error || "registry unavailable"; return }
            const kdeItems = o.items.filter(i => i.source === "kde")
            if (kdeItems.length === 0) return
            const cats = [...new Set(kdeItems.map(i => i.category))]
            let listings = []
            kdePending = cats.length
            pending += 0  // world fetch already counted
            cats.forEach(function (c) {
                page.bridge.kde(c, "", function (lo) {
                    kdePending--
                    if (lo.ok) listings = listings.concat(lo.items)
                    if (kdePending === 0) {
                        kdeItems.forEach(function (inst) {
                            const fresh = listings.find(l => String(l.ocsId) === String(inst.key.split("-")[1]))
                            if (fresh && fresh.version && fresh.version !== inst.version)
                                kdeRows.push({ title: inst.title, oldV: inst.version, newV: fresh.version, entry: fresh })
                        })
                        if (pending === 0) finish()
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
                    MouseArea { anchors.fill: parent; onClicked: {
                    if (modelData.worldId) page.bridge.installWorld(modelData.worldId, function () { page.reload() })
                    else { page.bridge.installKde(modelData.entry); page.reload() }
                } }
                }
            }
        }
    }
}
