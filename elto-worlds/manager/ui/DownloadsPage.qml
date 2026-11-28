// Downloads: this session's installs (worlds applied, KDE parts imported)
// with their honest outcome.
import QtQuick

Item {
    id: page
    property var st: ManagerStyle {}
    property StoreBridge bridge: null

    Column {
        x: 16; y: 16; width: page.width - 32; spacing: 8
        Text { text: "THIS SESSION"; color: page.st.gold; font.pixelSize: 10; font.letterSpacing: 2 }
        Repeater {
            model: page.bridge ? page.bridge.history : []
            Rectangle {
                required property string title
                required property string state
                required property string detail
                width: parent.width; height: 56; radius: page.st.radiusSmall
                color: "#ffffff"; border.width: 1; border.color: page.st.line
                Column {
                    x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100
                    Text { text: title; color: page.st.ink; font.pixelSize: 14; font.bold: true }
                    Text { visible: detail !== ""; text: detail; color: page.st.muted; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                }
                Rectangle {
                    x: parent.width - 88; anchors.verticalCenter: parent.verticalCenter
                    width: 74; height: 24; radius: 12
                    color: state === "done" ? page.st.accent : (state === "failed" ? page.st.gold : page.st.paper2)
                    Text { anchors.centerIn: parent; text: state; color: state === "running" ? page.st.ink : "#ffffff"; font.pixelSize: 11 }
                }
            }
        }
        Text {
            visible: !page.bridge || page.bridge.history.count === 0
            text: "Nothing this session. Downloads verify data-only before install; nothing runs from them."
            color: page.st.muted; font.pixelSize: 12
        }
    }
}
