// Shared toggle switch. Same look as the Soft motion toggle in Customize.
import QtQuick
import "../panel-widgets"

Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 54
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: root.checked ? Theme.color("midGreen") : Theme.divider
        Behavior on color { ColorAnimation { duration: Theme.ms(150) } }
        Rectangle {
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            width: 24
            height: 24
            radius: 12
            color: Theme.surface
            Behavior on x { NumberAnimation { duration: Theme.ms(150); easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
