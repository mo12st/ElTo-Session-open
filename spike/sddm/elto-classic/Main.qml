// ElTo SDDM theme "Classic Edition" (second login look, next to the painting theme).
// Design: concept C of the v5 series (owner picked it, Telegram 16060236, and asked for a
// session switch button). Left-aligned editorial layout on aquarelle paper.
// Qt6 greeter: no TextConstants context property, plain strings only.
import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#F4F1E8"

    property string ink: "#2C3A30"
    property string mut: "#5C6A58"
    property string deep: "#3E4A3A"
    property string clay: "#A06E52"
    property string alert: "#8A5A3F"
    property string serif: "Noto Serif Display"
    property real lx: 111

    Image {
        anchors.fill: parent
        source: "Background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    // Everything is designed on a 1920x1080 stage and scaled to the real screen,
    // so the layout is identical at any resolution.
    Item {
        id: stage
        width: 1920
        height: 1080
        property real k: Math.min(root.width / 1920, root.height / 1080)
        scale: k
        transformOrigin: Item.TopLeft
        x: (root.width - 1920 * k) / 2
        y: (root.height - 1080 * k) / 2

        // thin double plate frame
        Rectangle { x: 28; y: 28; width: stage.width - 56; height: stage.height - 56; color: "transparent"; border.color: "#668A9380"; border.width: 1 }
        Rectangle { x: 38; y: 38; width: stage.width - 76; height: stage.height - 76; color: "transparent"; border.color: "#448A9380"; border.width: 1 }

        // masthead strip
        Text {
            x: root.lx; y: 62
            color: root.ink; font.family: "Nunito"; font.weight: Font.DemiBold
            font.pointSize: 11.25; font.letterSpacing: 5; text: "ELTO OS"
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: root.lx; y: 62
            color: root.mut; font.family: "Nunito"; font.weight: Font.DemiBold
            font.pointSize: 9.75; font.letterSpacing: 5; text: "THE CLASSIC EDITION"
        }
        Rectangle { x: root.lx; y: 92; width: stage.width - 2 * root.lx; height: 2; color: root.ink }
        Rectangle { x: root.lx; y: 98; width: stage.width - 2 * root.lx; height: 1; color: "#808A9380" }

        // logo + wordmark
        Image {
            id: logo
            x: root.lx; y: 128
            width: 104; height: 78
            source: "assets/snail.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        Text {
            x: root.lx + 134; y: 134
            color: root.mut; font.family: "Nunito"; font.pointSize: 10.5; font.letterSpacing: 6
            text: "AQUARELLE SYSTEM"
        }
        Text {
            id: wordmark
            x: root.lx + 132; y: 150
            color: root.deep; font.family: root.serif; font.weight: Font.Light
            font.pointSize: 46.5; text: "ElTo"
        }
        Rectangle { x: root.lx + 134; y: 222; width: 120; height: 2; color: root.clay }

        // clock, date, greeting
        Text {
            id: clock
            x: root.lx - 4; y: 262
            color: root.ink; font.family: root.serif; font.weight: Font.ExtraLight
            font.pointSize: 157.5
            text: Qt.formatTime(new Date(), "hh:mm")
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm") }
        }
        Text {
            id: dateLine
            x: root.lx; y: clock.y + clock.height + 2
            color: root.ink; font.family: root.serif; font.italic: true; font.weight: Font.Light
            font.pointSize: 25.5
            text: Qt.formatDate(new Date(), "dddd, d MMMM")
        }
        Text {
            id: greeting
            x: root.lx; y: dateLine.y + dateLine.height + 8
            color: root.mut; font.family: "Nunito"; font.pointSize: 11.25; font.letterSpacing: 5
            text: {
                const h = new Date().getHours();
                const part = h < 5 ? "GOOD NIGHT" : h < 12 ? "GOOD MORNING" : h < 17 ? "GOOD AFTERNOON" : "GOOD EVENING";
                return part + ", " + userBox.currentText.toUpperCase();
            }
        }

        // hidden models that hold the real user and session lists
        ComboBox { id: userBox; visible: false; model: userModel; currentIndex: userModel.lastIndex; textRole: "name" }
        ComboBox { id: sessionBox; visible: false; model: sessionModel; currentIndex: sessionModel.lastIndex; textRole: "name" }

        // sign-in card
        Rectangle {
            id: card
            x: root.lx; y: greeting.y + greeting.height + 26
            width: 420; height: 214; radius: 22
            color: "#FBFAF5"; border.color: "#B5BBA9"; border.width: 1

            Text {
                x: 28; y: 22
                color: root.mut; font.family: "Nunito"; font.pointSize: 9; font.letterSpacing: 4
                text: "ENTER PASSWORD"
            }
            TextField {
                id: password
                x: 28; y: 46; width: parent.width - 56; height: 42
                echoMode: TextInput.Password
                color: root.ink
                font.family: "Nunito"; font.pointSize: 15.75
                leftPadding: 0; rightPadding: 0; topPadding: 6; bottomPadding: 6
                focus: true
                background: Rectangle { y: parent.height - 2; height: 2; color: password.activeFocus ? root.deep : "#6E7A6A" }
                Keys.onReturnPressed: loginButton.go()
                Keys.onEnterPressed: loginButton.go()
            }
            Text {
                id: notice
                x: 28; y: 96; width: parent.width - 56
                color: root.alert; font.family: "Nunito"; font.pointSize: 10.5; font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }
            Rectangle {
                id: loginButton
                x: 28; y: 126; width: parent.width - 56; height: 46; radius: 12
                color: loginArea.pressed ? "#2F3A2D" : root.deep
                function go() { sddm.login(userBox.currentText, password.text, sessionBox.currentIndex) }
                activeFocusOnTab: true
                                Keys.onReturnPressed: go(); Keys.onEnterPressed: go(); Keys.onSpacePressed: go()
                Rectangle { anchors.fill: parent; anchors.margins: -4; radius: 15; color: "transparent"; border.color: root.ink; border.width: 2; visible: loginButton.activeFocus }
                Text {
                    anchors.centerIn: parent
                    color: "#F4F1E8"; font.family: "Nunito"; font.weight: Font.Bold
                    font.pointSize: 11.25; font.letterSpacing: 6; text: "LOG IN"
                }
                MouseArea { id: loginArea; anchors.fill: parent; onClicked: loginButton.go() }
            }
            // session switch: one tap moves to the next installed session
            Item {
                id: sessionSwitch
                x: 28; y: 180; width: parent.width - 56; height: 26
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 150 - 10; elide: Text.ElideRight
                    color: root.mut; font.family: "Nunito"; font.pointSize: 9; font.letterSpacing: 1
                    text: sessionBox.currentText.toUpperCase()
                }
                Rectangle {
                    id: switchPill
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    activeFocusOnTab: sessionBox.count > 1
                    function cycle() { if (sessionBox.count > 1) sessionBox.currentIndex = (sessionBox.currentIndex + 1) % sessionBox.count }
                    Keys.onReturnPressed: cycle(); Keys.onEnterPressed: cycle(); Keys.onSpacePressed: cycle()
                    width: 150; height: 24; radius: 12
                    color: "transparent"; border.color: root.deep; border.width: switchPill.activeFocus ? 3 : 1
                    opacity: sessionBox.count > 1 ? 1 : 0.4
                    Text {
                        anchors.centerIn: parent
                        color: root.deep; font.family: "Nunito"; font.weight: Font.DemiBold
                        font.pointSize: 8.25; font.letterSpacing: 1.5; text: "SWITCH SESSION"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: sessionBox.count > 1
                        onClicked: switchPill.cycle()
                    }
                }
            }
        }

        // footer: power actions
        Rectangle { x: root.lx; y: stage.height - 118; width: stage.width - 2 * root.lx; height: 1; color: "#808A9380" }
        Row {
            x: root.lx; y: stage.height - 96
            spacing: 26
            Repeater {
                model: [
                    { label: "SLEEP", ok: sddm.canSuspend },
                    { label: "RESTART", ok: sddm.canReboot },
                    { label: "SHUT DOWN", ok: sddm.canPowerOff }
                ]
                delegate: Row {
                    id: pw
                    required property var modelData
                    required property int index
                    visible: modelData.ok
                    spacing: 26
                    Text {
                        id: pwText
                        activeFocusOnTab: true
                        function act() {
                            if (pw.index === 0) sddm.suspend();
                            else if (pw.index === 1) sddm.reboot();
                            else sddm.powerOff();
                        }
                        Keys.onReturnPressed: act(); Keys.onSpacePressed: act()
                        Rectangle { anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.color: root.ink; border.width: 2; radius: 6; visible: pwText.activeFocus }
                        color: (pwArea.containsMouse || pwText.activeFocus) ? root.ink : root.mut
                        font.family: "Nunito"; font.pointSize: 11.25; font.letterSpacing: 5
                        text: pw.modelData.label
                        MouseArea {
                            id: pwArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (pw.index === 0) sddm.suspend();
                                else if (pw.index === 1) sddm.reboot();
                                else sddm.powerOff();
                            }
                        }
                    }
                    Rectangle { visible: pw.index < 2; width: 5; height: 5; radius: 3; color: root.clay; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

    }

    Connections {
        target: sddm
        function onLoginFailed() { password.text = ""; notice.text = "! Login failed: wrong password, try again."; password.forceActiveFocus() }
        function onLoginSucceeded() { notice.text = "" }
    }
}
