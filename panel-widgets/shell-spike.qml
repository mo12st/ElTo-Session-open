// CONCEPT / SPIKE, not a design. Run: quickshell -p panel-widgets/shell-spike.qml
// Palette matches spike/shell.qml. Uses only Quickshell built-ins, no Plasma imports.
import Quickshell
import QtQuick

ShellRoot {
    PanelWindow {
        anchors {
            left: true
            right: true
            bottom: true
        }
        implicitHeight: 56
        color: "#f6f1e4"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "CONCEPT-SPIKE"
            color: "#a05040"
            font.pixelSize: 16
        }

        TaskbarPills {
            anchors.left: parent.left
            anchors.leftMargin: 180
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: Math.min(contentWidth, parent.width - 600)
        }

        Panel {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

