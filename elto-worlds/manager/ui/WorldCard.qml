// One store card: a world or a KDE part. kind=code items are greyed and
// link out to their source instead of installing (data-only rule).
// Worlds get a palette strip from their real colors; KDE items get their
// OCS preview thumbnail when the store provides one.
import QtQuick

Rectangle {
    id: card
    property var st: ManagerStyle {}
    property var item: ({})
    property string source: "elto"   // elto | kde
    signal installRequested(var item)

    readonly property bool isCode: item.kind === "code"
    readonly property var palette: {
        const c = item.colors
        if (!c) return []
        const out = []
        for (const k in c) if (out.length < 5 && /^#[0-9a-fA-F]{6}$/.test(c[k])) out.push(c[k])
        return out
    }

    width: 284; height: 132; radius: st.radius
    color: isCode ? st.paper2 : "#ffffff"
    border.width: 1
    border.color: ma.containsMouse && !isCode ? st.accent : st.line

    Row {
        x: 14; y: 12; width: parent.width - 28; spacing: 12
        // KDE preview thumbnail, or a soft placeholder with the category
        // initial when the store has no image for the item.
        Rectangle {
            visible: card.source === "kde"
            width: 64; height: 64; radius: card.st.radiusSmall
            color: card.st.paper2; border.width: 1; border.color: card.st.line
            clip: true
            Image {
                id: thumb
                anchors.fill: parent
                source: card.item.preview || ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: thumb.status !== Image.Ready
                text: (card.item.title || "?").charAt(0).toUpperCase()
                color: card.st.muted; font.pixelSize: 22; font.bold: true
            }
        }
        Column {
            width: parent.width - (card.source === "kde" ? 76 : 0); spacing: 4
            Row {
                width: parent.width
                Text {
                    text: card.item.label || card.item.title || ""
                    color: card.isCode ? card.st.muted : card.st.ink
                    font.pixelSize: 16; font.bold: true
                    width: parent.width - badge.width - 8; elide: Text.ElideRight
                }
                Rectangle {
                    id: badge
                    width: btxt.implicitWidth + 14; height: 20; radius: 10
                    color: card.source === "elto" ? card.st.accent : card.st.paper2
                    Text { id: btxt; anchors.centerIn: parent; text: card.source === "elto" ? "ELTO" : "KDE"
                           color: card.source === "elto" ? card.st.cream : card.st.ink; font.pixelSize: 9; font.bold: true }
                }
            }
            Text {
                text: card.item.story || card.item.summary || ""
                color: card.st.muted; font.pixelSize: 11
                width: parent.width; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap
                height: 30
            }
            Text {
                visible: text !== ""
                text: card.isCode ? "contains code - data-only rule keeps it listing-only"
                    : (card.item.author ? "by " + card.item.author : "") + (card.item.license ? "  -  " + card.item.license : "")
                color: card.st.gold; font.pixelSize: 10; width: parent.width; elide: Text.ElideRight
            }
        }
    }

    // palette strip: the world's own colors, straight from the catalog
    Row {
        visible: card.palette.length > 0
        x: 14; y: parent.height - 18; spacing: 5
        Repeater {
            model: card.palette
            Rectangle {
                required property var modelData
                width: 14; height: 14; radius: 7
                color: modelData; border.width: 1; border.color: card.st.line
            }
        }
    }

    Rectangle {
        x: parent.width - 106; y: parent.height - 42; width: 92; height: 28; radius: 14
        color: card.isCode ? "transparent" : (ma.containsMouse ? card.st.accentHi : card.st.accent)
        border.width: card.isCode ? 1 : 0; border.color: card.st.line
        Text {
            anchors.centerIn: parent
            text: card.isCode ? "Source" : "Install"
            color: card.isCode ? card.st.muted : "#ffffff"; font.pixelSize: 12; font.bold: true
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            onClicked: card.installRequested(card.item)
        }
    }
}
