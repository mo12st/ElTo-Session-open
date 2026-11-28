// One rice card (rices.json): a curated upstream KDE theme repo. Curated
// cards install the reviewed, commit-pinned data subset; everything else
// links out to GitHub. The card always shows what ElTo applies as data and
// what stays link-only (data-only rule), with license and activity honest.
import QtQuick

Rectangle {
    id: card
    property var st: ManagerStyle {}
    property var item: ({})
    signal installRequested(var item)

    readonly property bool installable: !!item.curated

    width: 304; height: 174; radius: st.radius
    color: installable ? "#ffffff" : st.paper2
    border.width: 1; border.color: st.line

    Column {
        x: 14; y: 12; width: parent.width - 28; spacing: 3
        Row {
            width: parent.width
            Text {
                text: card.item.label || ""
                color: card.installable ? card.st.ink : card.st.muted
                font.pixelSize: 15; font.bold: true
                width: parent.width - badge.width - 8; elide: Text.ElideRight
            }
            Rectangle {
                id: badge
                width: btxt.implicitWidth + 14; height: 20; radius: 10
                color: card.st.paper2; border.width: 1; border.color: card.st.line
                Text { id: btxt; anchors.centerIn: parent; text: "GITHUB"
                       color: card.st.ink; font.pixelSize: 9; font.bold: true }
            }
        }
        Text {
            text: (card.item.license || "?") + "  -  " + (card.item.stars || 0) + " stars  -  last push " + (card.item.lastPush || "?")
            color: card.st.muted; font.pixelSize: 10; width: parent.width; elide: Text.ElideRight
        }
        Text {
            visible: text !== ""
            text: "ElTo applies: " + ((card.item.applies || []).join(", ") || "nothing (code)")
            color: card.st.ink; font.pixelSize: 10
            width: parent.width; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight
            height: visible ? 26 : 0
        }
        Text {
            visible: text !== ""
            text: "Link only: " + ((card.item.linksOnly || []).join(", "))
            color: card.st.gold; font.pixelSize: 10
            width: parent.width; maximumLineCount: 3; wrapMode: Text.WordWrap; elide: Text.ElideRight
            height: visible ? 38 : 0
        }
        Text {
            visible: text !== ""
            text: card.item.curationPending ? "Data applies - reviewed pinned subset not built yet"
                : (card.item.kind === "code" ? "Compiled code - ElTo does not build or install it" : (card.item.note || ""))
            color: card.st.muted; font.pixelSize: 9; font.italic: true
            width: parent.width; elide: Text.ElideRight
        }
    }

    Rectangle {
        x: parent.width - 106; y: parent.height - 40; width: 92; height: 28; radius: 14
        color: card.installable ? (ma.containsMouse ? card.st.accentHi : card.st.accent) : "transparent"
        border.width: card.installable ? 0 : 1; border.color: card.st.line
        Text {
            anchors.centerIn: parent
            text: card.installable ? "Install" : "GitHub"
            color: card.installable ? "#ffffff" : card.st.muted; font.pixelSize: 12; font.bold: true
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            onClicked: card.installRequested(card.item)
        }
    }
}
