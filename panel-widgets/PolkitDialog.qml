// Native polkit authentication agent + dialog in the ElTo style (concept image reviewed). UNVERIFIED until a VM run.
// Registers as the session's polkit agent through Quickshell.Services.Polkit and shows one card per request.
// Colours, radii and fonts come from Theme only. Wrong password: the field shakes, the card stays open.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Controls

PanelWindow {
    id: win

    readonly property var flow: agent.flow
    readonly property string who: flow && flow.selectedIdentity ? flow.selectedIdentity.displayName : ""

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    // Always mapped: a visible binding to a runtime flag never showed the window under KWin (VM runs; same as NotificationPopups).
    // The mask is empty while idle, so the window never blocks clicks.
    visible: true
    mask: Region { item: dim }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: agent.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    PolkitAgent {
        id: agent
        Component.onCompleted: console.warn("POLKITREG completed isRegistered=" + isRegistered)
        onIsRegisteredChanged: console.warn("POLKITREG isRegistered=" + isRegistered)
        onAuthenticationRequestStarted: console.warn("POLKITREG request started")
    }

    Rectangle {
        id: dim
        width: agent.isActive ? parent.width : 0
        height: agent.isActive ? parent.height : 0
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
    }

    Rectangle {
        id: card
        width: 460
        height: 330
        radius: Theme.radiusWindow
        color: Theme.surface
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        visible: agent.isActive

        // soft shadow
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: Theme.shadowOffsetY
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, Theme.shadowAlpha)
        }

        // lock glyph on a selection-coloured disc
        Rectangle {
            x: 30; y: 28; width: 44; height: 44; radius: 22
            color: Theme.selection
            Rectangle { x: 15; y: 11; width: 14; height: 14; radius: 7; color: "transparent"; border.width: 3; border.color: Theme.text }
            Rectangle { x: 13; y: 20; width: 18; height: 14; radius: 3; color: Theme.text }
        }
        Text {
            x: 88; y: 22
            text: "Allow this change?"
            font.family: Theme.serif; font.pixelSize: 26
            color: Theme.text
        }
        Text {
            x: 88; y: 60; width: parent.width - 118
            text: win.flow ? win.flow.message : ""
            elide: Text.ElideRight
            font.family: Theme.sans; font.pixelSize: 15
            color: Theme.textMuted
        }
        Rectangle { x: 30; y: 98; width: parent.width - 60; height: 2; color: Theme.divider }
        Text {
            x: 30; y: 112
            text: "This needs an administrator."
            font.family: Theme.sans; font.pixelSize: 15
            color: Theme.text
        }
        Text {
            x: 30; y: 138
            text: win.who !== "" ? "Enter the password for " + win.who + "." : "Enter your password."
            font.family: Theme.sans; font.pixelSize: 13
            color: Theme.textMuted
        }

        Rectangle {
            id: field
            x: 30; y: 170; width: parent.width - 60; height: 44
            radius: Theme.radiusCard
            color: Theme.surfaceAlt
            border.width: 2
            border.color: failedHint.visible ? Theme.accent : Theme.textMuted

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                echoMode: win.flow && win.flow.responseVisible ? TextInput.Normal : TextInput.Password
                font.family: Theme.sans; font.pixelSize: 15; font.bold: true
                color: Theme.text
                focus: true
                onAccepted: { if (win.flow && text.length > 0) { console.warn('POLKITFLOW submit len=' + text.length + ' respReq=' + win.flow.isResponseRequired); win.flow.submit(text) } }
            }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "x"; to: 22; duration: 50 }
                NumberAnimation { target: field; property: "x"; to: 38; duration: 70 }
                NumberAnimation { target: field; property: "x"; to: 26; duration: 60 }
                NumberAnimation { target: field; property: "x"; to: 30; duration: 50 }
            }
        }
        Text {
            id: failedHint
            x: 32; y: 220
            visible: false
            text: "Wrong password: field shakes, dialog stays open"
            font.family: Theme.sans; font.pixelSize: 12
            color: Theme.disabled
        }

        Rectangle {
            x: parent.width - 30 - 106 - 14 - 106; y: 248; width: 106; height: 44; radius: 22
            color: Theme.divider
            Text { anchors.centerIn: parent; text: "Cancel"; font.family: Theme.sans; font.pixelSize: 15; font.bold: true; color: Theme.text }
            MouseArea { anchors.fill: parent; onClicked: if (win.flow) win.flow.cancelAuthenticationRequest() }
        }
        Rectangle {
            x: parent.width - 30 - 106; y: 248; width: 106; height: 44; radius: 22
            color: Theme.accent
            Text { anchors.centerIn: parent; text: "Allow"; font.family: Theme.sans; font.pixelSize: 15; font.bold: true; color: Theme.surface }
            MouseArea { anchors.fill: parent; onClicked: if (win.flow && pw.text.length > 0) win.flow.submit(pw.text) }
        }

        Keys.onEscapePressed: if (win.flow) win.flow.cancelAuthenticationRequest()
    }

    Connections {
        target: win.flow
        function onIsCompletedChanged() { console.warn("POLKITFLOW completed=" + win.flow.isCompleted + " ok=" + win.flow.isSuccessful + " cancelled=" + win.flow.isCancelled) }
        function onIsResponseRequiredChanged() { console.warn("POLKITFLOW responseRequired=" + win.flow.isResponseRequired + " prompt=" + win.flow.inputPrompt) }
        function onSupplementaryMessageChanged() { console.warn("POLKITFLOW supp=" + win.flow.supplementaryMessage + " err=" + win.flow.supplementaryIsError) }
        function onAuthenticationFailed() {
            console.warn("POLKITFLOW authenticationFailed")
            failedHint.visible = true
            pw.text = ""
            pw.forceActiveFocus()
            shake.restart()
        }
    }
    Connections {
        target: agent
        function onIsActiveChanged() { console.warn("POLKITREG isActive=" + agent.isActive + " flow=" + (agent.flow ? agent.flow.message + " | ident=" + agent.flow.selectedIdentity : "null") + " dim=" + dim.width + "x" + dim.height + " card.visible=" + card.visible); if (agent.isActive) { failedHint.visible = false; pw.text = ""; pw.forceActiveFocus() } }
    }
    onVisibleChanged: if (false) { failedHint.visible = false; pw.text = ""; pw.forceActiveFocus() }
}
