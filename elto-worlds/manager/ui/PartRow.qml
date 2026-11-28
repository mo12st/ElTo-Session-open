// One installed row: enable/disable toggle, remove. Honest states only.
import QtQuick

Rectangle {
    id: row
    property var st: ManagerStyle {}
    property var item: ({})
    signal toggled(bool on)
    signal removeRequested()

    width: parent ? parent.width : 600; height: 64; radius: st.radiusSmall
    color: "#ffffff"; border.width: 1; border.color: st.line

    Column {
        x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 230
        Text { text: row.item.title || ""; color: st.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
        Text {
            text: (row.item.category || "") + "  -  v" + (row.item.version || "?") + "  -  " + (row.item.source === "kde" ? "KDE Store, converted data-only" : "ElTo")
            color: st.muted; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width
        }
    }

    Rectangle {
        id: tog
        x: parent.width - 196; anchors.verticalCenter: parent.verticalCenter
        width: 46; height: 26; radius: 13
        color: row.item.enabled ? row.st.accent : row.st.line
        Rectangle {
            y: 3; width: 20; height: 20; radius: 10; color: "#ffffff"
            x: row.item.enabled ? 23 : 3
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea { anchors.fill: parent; onClicked: row.toggled(!row.item.enabled) }
    }

    Text {
        x: parent.width - 120; anchors.verticalCenter: parent.verticalCenter
        text: "Remove"; color: row.st.gold; font.pixelSize: 12
        MouseArea { anchors.fill: parent; onClicked: row.removeRequested() }
    }
}
