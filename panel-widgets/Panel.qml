// CONCEPT / SPIKE panel strip, not a design. Composes the widgets in this directory.
import QtQuick

Row {
    spacing: 28

    Bluetooth {}
    Network {}
    Volume {}
    Battery {}
    Clock {}
}
