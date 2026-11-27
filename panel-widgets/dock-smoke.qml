// Load harness for the dock variants: the dock and nothing else, so a container can prove that each
// variant really instantiates in Quickshell. Run by dock-smoke.sh, never by the session.
import Quickshell
import QtQuick

ShellRoot {
    Dock {}
}
