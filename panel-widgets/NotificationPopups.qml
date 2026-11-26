// CONCEPT / SPIKE notification popups, UNVERIFIED until a VM run.
// Uses Quickshell's own notification server (org.freedesktop.Notifications). Palette and motion tokens from ElToPalette.
// Only one notification daemon can own the bus name: stop any other daemon (for example plasmashell's) before testing.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

PanelWindow {
    id: win

    property int popupSeconds: 6

    anchors {
        top: true
        right: true
    }
    margins {
        top: 12
        right: 12
    }
    implicitWidth: 360
    implicitHeight: 480
    color: "transparent"
    exclusiveZone: 0
    // Always mapped: a visible binding on the list count never showed the window under KWin (VM run 45841600027).
    // The mask keeps input only on the cards, so the empty window does not block clicks.
    visible: true
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {
        item: stack
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: false
        keepOnReload: false
        onNotification: n => {
            n.tracked = true;
        }
    }

    ListView {
        id: stack
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: Math.min(parent.height, contentHeight)
        interactive: false
        spacing: 8
        model: server.trackedNotifications

        delegate: Rectangle {
            id: card
            required property var modelData

            width: ListView.view.width
            implicitHeight: col.implicitHeight + 24
            height: implicitHeight
            radius: 14
            color: ElToPalette.cream
            border.width: 1
            border.color: modelData.urgency === NotificationUrgency.Critical ? ElToPalette.rust : ElToPalette.inactiveBg

            Column {
                id: col
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 4

                Text {
                    width: parent.width
                    text: card.modelData.summary
                    elide: Text.ElideRight
                    font.pixelSize: 15
                    font.bold: true
                    color: ElToPalette.text
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: card.modelData.body
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    color: ElToPalette.midGreen
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: card.modelData.dismiss()
            }

            Timer {
                running: card.modelData.urgency !== NotificationUrgency.Critical
                interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout * 1000 : win.popupSeconds * 1000
                onTriggered: card.modelData.expire()
            }
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: ElToPalette.popupMs
                    easing.type: ElToPalette.easing
                }
                NumberAnimation {
                    property: "x"
                    from: ElToPalette.popupSlidePx * 2
                    duration: ElToPalette.popupMs
                    easing.type: ElToPalette.easing
                }
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: ElToPalette.disappearMs
                easing.type: ElToPalette.easing
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: ElToPalette.popupMs
                easing.type: ElToPalette.easing
            }
        }
    }
}
