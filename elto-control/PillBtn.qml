// Small theme-driven pill button. primary = accent fill.
import QtQuick

Rectangle {
    id: b
    property string label: ""
    property string icon: ""
    property bool primary: false
    property bool enabledBtn: true
    signal clicked()
    implicitHeight: 38
    implicitWidth: row.implicitWidth + 32
    radius: height / 2
    color: primary ? Theme.accent : (ma.containsMouse && enabledBtn ? Theme.selection : Theme.surfaceAlt)
    border.width: primary ? 0 : 1; border.color: Theme.divider
    opacity: enabledBtn ? 1 : 0.5
    Row {
        id: row; anchors.centerIn: parent; spacing: 8
        LIcon { visible: b.icon !== ""; name: b.icon; size: 16; tint: b.primary ? Theme.surface : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Text { text: b.label; color: b.primary ? Theme.surface : Theme.text; font.family: Theme.sans; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: b.enabledBtn; onClicked: b.clicked() }
}
