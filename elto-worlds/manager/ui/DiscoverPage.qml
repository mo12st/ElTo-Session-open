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

    // KDE item details overlay (public store data only)
    property var detailItem: null
    property var detailInfo: null
    property int detailImg: 0
    property string detailNotice: ""

    function openDetail(it) {
        detailItem = it
        detailInfo = null
        detailImg = 0
        detailNotice = ""
        bridge.kdeDetail(it.id, function (o) {
            if (o.ok && page.detailItem === it) page.detailInfo = o.item
        })
    }

    function detailImages() {
        if (detailInfo && detailInfo.previews && detailInfo.previews.length > 0) return detailInfo.previews
        return detailItem && detailItem.preview ? [detailItem.preview] : []
    }

    readonly property bool isKde: category !== "worlds" && category !== "filemanager" && category !== "functions" && category !== "rices"

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
        } else if (category === "rices") {
            bridge.rices(function (o) { if (o.ok) page.items = o.items })
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
            cellWidth: page.category === "rices" ? 320 : 300
            cellHeight: page.category === "rices" ? 190 : 148; clip: true
            model: page.items.filter(page.matches)
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
                    onClicked: function (it) { if (page.category !== "worlds") page.openDetail(it) }
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
    }

    // KDE item details: name, author, version/date, downloads/score,
    // license, preview images, description and its store page - all from
    // the public OCS data the cards already use.
    Rectangle {
        anchors.fill: parent
        visible: page.detailItem !== null
        color: "#402b2b26"
        MouseArea { anchors.fill: parent; onClicked: page.detailItem = null }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 560)
            height: Math.min(parent.height - 48, 470)
            radius: page.st.radius; color: "#ffffff"
            border.width: 1; border.color: page.st.line
            MouseArea { anchors.fill: parent }  // taps inside do not close

            Flickable {
                anchors.fill: parent; anchors.margins: 20
                contentHeight: dcol.height; clip: true
                Column {
                    id: dcol
                    width: parent.width - 40; spacing: 10

                    Row {
                        width: parent.width; spacing: 14
                        Rectangle {
                            width: 132; height: 132; radius: page.st.radiusSmall
                            color: page.st.paper2; border.width: 1; border.color: page.st.line
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: page.detailImages().length > 0 ? page.detailImages()[page.detailImg % page.detailImages().length] : ""
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: page.detailItem ? (page.detailItem.title || "?").charAt(0).toUpperCase() : ""
                                color: page.st.muted; font.pixelSize: 30; font.bold: true
                            }
                            Text {
                                visible: page.detailImages().length > 1
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: " < "; color: page.st.accent; font.pixelSize: 14; font.bold: true
                                MouseArea { anchors.fill: parent; onClicked: page.detailImg = (page.detailImg + page.detailImages().length - 1) % page.detailImages().length }
                            }
                            Text {
                                visible: page.detailImages().length > 1
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: " > "; color: page.st.accent; font.pixelSize: 14; font.bold: true
                                MouseArea { anchors.fill: parent; onClicked: page.detailImg = (page.detailImg + 1) % page.detailImages().length }
                            }
                        }
                        Column {
                            width: parent.width - 146; spacing: 5
                            Text {
                                text: page.detailItem ? (page.detailItem.title || "") : ""
                                color: page.st.ink; font.pixelSize: 17; font.bold: true
                                width: parent.width; wrapMode: Text.WordWrap
                            }
                            Text {
                                visible: text !== ""
                                text: page.detailItem && page.detailItem.author ? "by " + page.detailItem.author : ""
                                color: page.st.muted; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight
                            }
                            Text {
                                visible: text !== ""
                                text: {
                                    if (!page.detailItem) return ""
                                    const bits = []
                                    if (page.detailItem.version) bits.push("v" + page.detailItem.version)
                                    const d = (page.detailInfo && (page.detailInfo.changed || page.detailInfo.created)) || ""
                                    if (d !== "") bits.push(d.split("T")[0])
                                    if (page.detailItem.typename) bits.push(page.detailItem.typename)
                                    return bits.join("  -  ")
                                }
                                color: page.st.muted; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight
                            }
                            Text {
                                visible: text !== ""
                                text: {
                                    if (!page.detailItem) return ""
                                    const bits = []
                                    if (page.detailItem.downloads && page.detailItem.downloads !== "") bits.push(page.detailItem.downloads + " downloads")
                                    if (page.detailItem.score && page.detailItem.score !== "") bits.push("score " + page.detailItem.score)
                                    if (page.detailItem.license && page.detailItem.license !== "") bits.push(page.detailItem.license)
                                    return bits.join("  -  ")
                                }
                                color: page.st.gold; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: page.detailInfo && page.detailInfo.description !== "" ? page.detailInfo.description
                            : (page.detailItem ? (page.detailItem.summary || "") : "")
                        color: page.st.ink; font.pixelSize: 12
                    }

                    Text {
                        visible: page.detailNotice !== ""
                        text: page.detailNotice; color: page.st.gold; font.pixelSize: 12
                        width: parent.width; wrapMode: Text.WordWrap
                    }

                    Row {
                        spacing: 10
                        Rectangle {
                            visible: page.detailItem && page.detailItem.kind !== "code"
                            width: 92; height: 30; radius: 15
                            color: dinstall.containsMouse ? page.st.accentHi : page.st.accent
                            Text { anchors.centerIn: parent; text: "Install"; color: "#ffffff"; font.pixelSize: 12; font.bold: true }
                            MouseArea {
                                id: dinstall; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    const it = page.detailItem
                                    page.bridge.installKde(it, function (o) {
                                        page.detailNotice = o.ok ? "Installed - find it under Installed, then Apply its parts there."
                                            : ("Install failed safely: " + (o.error || "unknown error"))
                                    })
                                }
                            }
                        }
                        Rectangle {
                            width: storeTxt.implicitWidth + 24; height: 30; radius: 15
                            color: "transparent"; border.width: 1; border.color: page.st.line
                            Text { id: storeTxt; anchors.centerIn: parent; text: "KDE Store page"; color: page.st.ink; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Qt.openUrlExternally((page.detailInfo && page.detailInfo.detailPage) || (page.detailItem && page.detailItem.detailPage) || "")
                            }
                        }
                        Rectangle {
                            width: closeTxt.implicitWidth + 24; height: 30; radius: 15
                            color: "transparent"; border.width: 1; border.color: page.st.line
                            Text { id: closeTxt; anchors.centerIn: parent; text: "Close"; color: page.st.muted; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: page.detailItem = null }
                        }
                    }
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
