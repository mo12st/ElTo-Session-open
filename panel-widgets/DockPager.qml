// The dock's workspace indicator: which virtual desktop is in use, drawn the way a world asks for.
// It only draws; DockDesktops.qml owns the KWin data and the switching, and the dock hands both in.
//   text     "01 · Personal", or "Desktop 2" when that desktop has no name of its own; a click moves on
//   numbers  one square per desktop, the current one filled; a click jumps to it
//   dots     one dot per desktop, the current one filled; a click jumps to it
//   none     nothing
// With a single desktop every style draws nothing: there is nothing to indicate, and a lone "Desktop 1"
// on a one-desktop session is noise. A world that omits workspaceStyle therefore looks unchanged.
import QtQuick

Row {
    id: root
    property string style: "text"    // text | numbers | dots | none
    property int count: 0
    property int index: -1
    property string name: ""
    property int textSize: 13
    property color textColor: Theme.textMuted
    property color accent: Theme.accent
    property color chipColor: Theme.selection
    signal pick(int i)

    visible: style !== "none" && count > 1
    spacing: style === "dots" ? 5 : (style === "numbers" ? 4 : 0)

    Text {
        visible: root.style === "text"
        anchors.verticalCenter: parent.verticalCenter
        text: {
            var n = root.index + 1
            if (n < 1) n = 1
            var plain = "Desktop " + n
            var label = root.name
            if (label === "" || label === plain) return plain
            return (n < 10 ? "0" + n : "" + n) + " · " + label
        }
        color: root.textColor
        font.family: Theme.serif
        font.pixelSize: root.textSize
        renderType: Text.NativeRendering
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pick((root.index + 1) % root.count)
        }
    }

    Repeater {
        model: root.style === "numbers" ? root.count : 0
        Rectangle {
            required property int index
            width: 18; height: 18; radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: index === root.index ? root.chipColor : "transparent"
            border.width: index === root.index ? 0 : 1
            border.color: Theme.divider
            Text {
                anchors.centerIn: parent
                text: index + 1
                color: Theme.text
                font.family: Theme.serif
                font.pixelSize: Math.max(9, root.textSize - 3)
                renderType: Text.NativeRendering
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick(index)
            }
        }
    }

    Repeater {
        model: root.style === "dots" ? root.count : 0
        Rectangle {
            required property int index
            width: 6; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: index === root.index ? root.accent : Theme.divider
            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick(index)
            }
        }
    }
}
