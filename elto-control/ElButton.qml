// Shared pill button.
import QtQuick
import "../panel-widgets"

Rectangle {
    id: root

    property string text: ""
    property bool danger: false
    property bool busy: false
    signal clicked()

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 34
    radius: 17
    color: root.danger ? Theme.color("rust") : (area.containsMouse ? Theme.selection : Theme.surface)
    border.width: 1
    border.color: Theme.divider
    opacity: root.busy ? 0.6 : 1

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.danger ? Theme.surface : Theme.text
        font.family: Theme.sans
        font.pixelSize: 14
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.BusyCursor : Qt.PointingHandCursor
        onClicked: if (!root.busy) root.clicked()
    }
}
