// CONCEPT / SPIKE widget, not a design. Quickshell built-ins only (SystemClock), no Plasma imports.
// Written from the Quickshell docs; DMS (MIT) only referenced for the idea of one small file per widget.
import QtQuick
import Quickshell

Text {
    id: root

    property string format: "ddd d MMM  HH:mm"
    property color textColor: "#283a32"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, root.format)
    color: root.textColor
    font.pixelSize: 20
}
