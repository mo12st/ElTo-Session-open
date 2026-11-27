// Shared settings row: title on the leading side, caller's controls on the trailing side.
// Usage:
//   ElRow { title: I18n.t("volume"); ElToggle { ... } }
import QtQuick

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: payload.children

    height: root.subtitle === "" ? 44 : 62
    radius: Theme.radiusCard
    color: Theme.surfaceAlt

    Column {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - payload.width - 44, parent.width)
        Text {
            text: root.title
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: 15
        }
        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.textMuted
            font.family: Theme.sans
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width
        }
    }

    Row {
        id: payload
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
