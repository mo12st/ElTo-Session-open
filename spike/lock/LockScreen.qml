import QtQuick
import QtQuick.Controls as QQC2

// SPIKE lock screen: password field, no import of org.kde.plasma.private.sessions. Not a design.
Item {
    id: root
    property bool locked: false
    property bool capsLockOn: false
    signal unlockRequested()

    Rectangle { anchors.fill: parent; color: "#efe9d8" }
    Column {
        anchors.centerIn: parent
        spacing: 14
        Text { text: "ElTo"; font.pixelSize: 56; font.family: "serif"; color: "#283a32"; anchors.horizontalCenter: parent.horizontalCenter }
        Text { text: "SPIKE LOCK SCREEN (not a design)"; font.pixelSize: 18; color: "#a05040"; anchors.horizontalCenter: parent.horizontalCenter }
        QQC2.TextField {
            id: pw
            width: 320
            echoMode: TextInput.Password
            placeholderText: "Password"
                        Keys.onReturnPressed: { console.log("SPIKELOCK enter len=" + pw.text.length + " txt=" + pw.text); authenticator.respond(pw.text) }
            Keys.onEnterPressed: authenticator.respond(pw.text)
        }
        Text { id: note; text: ""; font.pixelSize: 18; color: "#a05040"; anchors.horizontalCenter: parent.horizontalCenter }
    }
    Connections {
        target: authenticator
        function onFailed(kind) { if (kind !== 0) return; note.text = "Unlocking failed"; pw.text = ""; console.log("SPIKELOCK failed"); authenticator.startAuthenticating() }
        function onSucceeded() { console.log("SPIKELOCK succeeded"); authenticator.stopAuthenticating(); Qt.quit() }
    }
    Timer { interval: 1000; running: !authenticator.unlocked; repeat: true; onTriggered: authenticator.startAuthenticating() }
    Component.onCompleted: { authenticator.startAuthenticating(); pw.forceActiveFocus(); console.log("SPIKELOCK greeter qml loaded") }
}
