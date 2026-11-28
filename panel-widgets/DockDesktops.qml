// Virtual desktops for the dock pager, read from KWin over D-Bus by dock-desktops.py.
// KWin publishes them at org.kde.KWin /VirtualDesktopManager (count, current, desktops); Quickshell
// has no D-Bus property binding, so the helper prints one record per line and this file turns that
// into a model. The dock polls it every two seconds and once after every switch: a pager that lags a
// moment is invisible, and a real signal subscription would need a second long-lived helper.
// KWin not answering (no session bus, a different compositor) leaves count at 0, and the pager then
// draws nothing at all rather than a wrong desktop number.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    // python3 is already a session dependency: the Themes page runs theme-tool.py the same way
    property string helper: Quickshell.env("ELTO_DESKTOPS") || Quickshell.shellPath("dock-desktops.py")
    property bool enabled: true
    property int pollMs: 2000

    readonly property var names: _names
    readonly property var ids: _ids
    readonly property int count: _names.length
    readonly property int currentIndex: _index
    readonly property bool ok: _ok
    readonly property string currentName: (_index >= 0 && _index < _names.length) ? _names[_index] : ""

    property var _names: []
    property var _ids: []
    property int _index: -1
    property bool _ok: false
    property var _lines: []

    // 0-based, the way the pager counts; the helper takes the 1-based number the desktop is drawn with
    // one line when the desktop count changes: the smoke test uses it to prove the D-Bus read ran
    onCountChanged: console.log("ELTODOCKDESK " + count + " desktops, at " + (_index + 1))

    function switchTo(i) {
        if (i < 0 || i >= _ids.length) return
        sw.command = ["python3", root.helper, "switch", String(i + 1)]
        sw.running = true
        console.log("ELTODOCKDESK switch " + (i + 1) + " of " + _ids.length)
    }
    function next() { if (count > 1) switchTo((_index + 1) % count) }

    function commit() {
        var names = [], ids = [], current = "", ok = false
        for (var i = 0; i < _lines.length; i++) {
            var p = _lines[i].split(" ")
            if (p[0] === "count") ok = true
            else if (p[0] === "current") current = p.slice(1).join(" ")
            else if (p[0] === "desktop" && p.length >= 4) { ids.push(p[2]); names.push(p.slice(3).join(" ")) }
        }
        _lines = []
        _ok = ok
        if (!ok) { _names = []; _ids = []; _index = -1; return }
        _names = names
        _ids = ids
        var at = ids.indexOf(current)
        if (at >= 0) _index = at
        else _index = (current !== "" && !isNaN(parseInt(current))) ? parseInt(current) - 1 : -1
    }

    Process {
        id: probe
        command: ["python3", root.helper]
        stdout: SplitParser { onRead: line => root._lines.push(line) }
        onExited: root.commit()
    }
    Process {
        id: sw
        command: ["python3", root.helper, "switch", "1"]
        onExited: tick.restart()
    }
    Timer {
        id: tick
        interval: root.pollMs
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }
}
