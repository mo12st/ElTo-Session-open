// Discover: ElTo worlds from the repo catalog, or a KDE Store category
// (read-only). Data items install; code items are greyed and link out.
// The search box queries the KDE Store live on KDE categories and filters
// the local lists (worlds, functions) client-side.
import QtQuick
import QtQuick.Layouts

Item {
    id: page
    property var st: ManagerStyle {}
    property StoreBridge bridge: null
    property string category: "worlds"

    property var items: []
    property string notice: ""
    property string search: ""

    readonly property bool isKde: category !== "worlds" && category !== "filemanager" && category !== "functions"

    function matches(it) {
        if (page.search === "" || page.isKde) return true
        const q = page.search.toLowerCase()
        return ((it.label || it.title || "") + " " + (it.story || it.summary || "")).toLowerCase().indexOf(q) >= 0
    }

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
        } else {
            notice = page.search === "" ? "loading KDE Store (read-only)..." : "searching KDE Store..."
            bridge.kde(category, page.search, function (o) {
                if (o.ok) { page.items = o.items; page.notice = o.stale ? "KDE Store unreachable - showing a cached listing" : "" }
                else page.notice = o.error || "KDE Store unavailable"
            })
        }
    }
    onCategoryChanged: { searchBox.text = ""; page.search = ""; reload() }
    Component.onCompleted: reload()

    // debounce: one live store query when typing pauses, not one per key
    Timer {
        id: searchTimer; interval: 350; repeat: false
        onTriggered: { page.search = searchBox.text.trim(); page.reload() }
    }

    Column {
        anchors.fill: parent; anchors.margins: 16; spacing: 12

        Rectangle {
            visible: page.category !== "filemanager"
            width: parent.width; height: 34; radius: 17
            color: "#ffffff"; border.width: 1
            border.color: searchBox.activeFocus ? page.st.accent : page.st.line
            TextInput {
                id: searchBox
                x: 16; width: parent.width - 32
                anchors.verticalCenter: parent.verticalCenter
                color: page.st.ink; font.pixelSize: 13
                clip: true
                onTextChanged: searchTimer.restart()
                Text {
                    anchors.fill: parent
                    visible: searchBox.text === ""
                    text: page.isKde ? "Search the KDE Store..." : "Filter..."
                    color: page.st.muted; font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Text {
            visible: page.notice !== ""
            text: page.notice; color: page.st.gold; font.pixelSize: 12; wrapMode: Text.WordWrap
            width: parent.width
        }

        GridView {
            width: parent.width
            height: parent.height - (page.notice !== "" ? 52 : 0) - (page.category !== "filemanager" ? 46 : 0)
            cellWidth: 300; cellHeight: 148; clip: true
            model: page.items.filter(page.matches)
            delegate: WorldCard {
                st: page.st
                item: modelData
                source: page.category === "worlds" ? "elto" : "kde"
                onInstallRequested: function (it) {
                    if (it.kind === "code") { Qt.openUrlExternally(it.detailPage || it.url || ""); return }
                    if (page.category === "worlds") page.bridge.installWorld(it.id)
                    else page.bridge.installKde(it, function (o) {
                        page.notice = o.ok ? "" : ("Install failed safely: " + (o.error || "unknown error"))
                    })
                }
            }
        }
    }

    // empty state: a real sentence, centered, instead of a blank grid
    Text {
        anchors.centerIn: parent
        visible: page.notice === "" && page.items.filter(page.matches).length === 0
        width: parent.width - 64
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: page.search !== "" ? "Nothing matches \"" + page.search + "\" here."
            : page.isKde ? "This category is empty right now."
            : page.category === "filemanager" ? ""
            : "Nothing here yet."
        color: page.st.muted; font.pixelSize: 13
    }
}
