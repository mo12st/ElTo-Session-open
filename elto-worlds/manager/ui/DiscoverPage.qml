// Discover: ElTo worlds from the repo catalog, or a KDE Store category
// (read-only). Data items install; code items are greyed and link out.
import QtQuick
import QtQuick.Layouts

Item {
    id: page
    property var st: ManagerStyle {}
    property StoreBridge bridge: null
    property string category: "worlds"

    property var items: []
    property string notice: ""

    function reload() {
        items = []
        if (!bridge) return
        if (category === "worlds") {
            notice = ""
            bridge.worlds(function (o) {
                if (o.ok) page.items = o.items
                else page.notice = o.error || "catalog unavailable"
            })
        } else if (category === "filemanager") {
            page.notice = "File manager looks arrive with the per-world filemanager block (schema decision pending)."
        } else if (category === "functions") {
            bridge.functions(function (o) { if (o.ok) page.items = o.items })
        } else if (category === "rices") {
            bridge.rices(function (o) { if (o.ok) page.items = o.items })
        } else {
            notice = "loading KDE Store (read-only)..."
            bridge.kde(category, function (o) {
                if (o.ok) { page.items = o.items; page.notice = o.stale ? "KDE Store unreachable - showing a cached listing" : "" }
                else page.notice = o.error || "KDE Store unavailable"
            })
        }
    }
    onCategoryChanged: reload()
    Component.onCompleted: reload()

    Column {
        anchors.fill: parent; anchors.margins: 16; spacing: 12
        Text {
            visible: page.notice !== ""
            text: page.notice; color: page.st.gold; font.pixelSize: 12; wrapMode: Text.WordWrap
            width: parent.width
        }
        GridView {
            width: parent.width; height: parent.height - (page.notice !== "" ? 40 : 0)
            cellWidth: page.category === "rices" ? 320 : 300
            cellHeight: page.category === "rices" ? 190 : 148; clip: true
            model: page.items
            delegate: Item {
                width: GridView.view.cellWidth; height: GridView.view.cellHeight
                RiceCard {
                    visible: page.category === "rices"
                    st: page.st
                    item: modelData
                    onInstallRequested: function (it) {
                        if (!it.curated) { Qt.openUrlExternally(it.upstream || ""); return }
                        page.bridge.installRice(it.id)
                    }
                }
                WorldCard {
                    visible: page.category !== "rices"
                    st: page.st
                    item: modelData
                    source: page.category === "worlds" ? "elto" : "kde"
                    onInstallRequested: function (it) {
                        if (it.kind === "code") { Qt.openUrlExternally(it.detailPage || it.url || ""); return }
                        if (page.category === "worlds") page.bridge.installWorld(it.id)
                        else page.bridge.installKde(it)
                    }
                }
            }
        }
    }
}
