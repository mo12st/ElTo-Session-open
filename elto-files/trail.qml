// Trail: ElTo file browser (v1) and the "This computer" page, as standalone Quickshell windows.
// Run: quickshell -p elto-files/trail.qml
// Start page: TRAIL_START=computer (This computer page) | an absolute folder path | (unset: home folder).
// v1 scope: browse, open (xdg-open), sidebar, breadcrumb, back/forward, drive cards with Eject.
// File operations (copy, move, delete, network) come later through KDE KIO, not copied Dolphin code.
// Theme is read like the welcome app: themes/soft-paper/theme.json + the user overlay, read-only.
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: app

    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: Quickshell.shellPath("trail-helper.py")
    readonly property string start: Quickshell.env("TRAIL_START") || ""
    property bool trailVisible: true
    property string trailGoto: start.indexOf("/") === 0 ? start : home
    property int gotoSerial: 0
    property var drives: []
    property var counts: ({})

    // ---- theme (same merge as welcome/welcome.qml) ----
    QtObject {
        id: th
        property var base: ({})
        property var user: ({})
        function section(name) {
            var out = {}, b = base[name] || {}, u = user[name] || {}
            for (var k in b) out[k] = b[k]
            for (var j in u) out[j] = u[j]
            return out
        }
        readonly property var colors: section("colors")
        readonly property var roles: section("roles")
        readonly property var shapeT: section("shape")
        readonly property var fonts: section("fonts")
        readonly property var options: section("options")
        function role(r) { var n = roles[r]; return colors[n] !== undefined ? colors[n] : (colors[r] !== undefined ? colors[r] : "#f6f1e4") }
        readonly property color surface: role("surface")
        readonly property color surfaceAlt: role("surfaceAlt")
        readonly property color text: role("text")
        readonly property color textMuted: role("textMuted")
        readonly property color accent: role("accent")
        readonly property color selection: role("selection")
        readonly property color divider: role("divider")
        readonly property int radiusWindow: shapeT.radiusWindow !== undefined ? shapeT.radiusWindow : 22
        readonly property int radiusCard: shapeT.radiusCard !== undefined ? shapeT.radiusCard : 14
        readonly property string serif: fonts.serif || "Noto Serif Display"
        readonly property string sans: fonts.sans || "Noto Sans"
        readonly property bool motion: options.motion !== "off"
        function ms(v) { return motion ? v : 0 }
    }
    FileView {
        path: Quickshell.shellPath("../themes/soft-paper/theme.json")
        blockLoading: true
        onLoaded: { try { th.base = JSON.parse(text()) } catch (e) { console.log("TRAIL base theme parse error " + e) } }
    }
    FileView {
        path: Quickshell.env("ELTO_THEME") || (Quickshell.env("HOME") + "/.config/elto/theme.json")
        blockLoading: true
        onLoaded: { try { th.user = JSON.parse(text()) } catch (e) { console.log("TRAIL user theme parse error " + e) } }
        onLoadFailed: th.user = ({})
    }
    readonly property var theme: th

    // ---- actions used by both windows ----
    function icon(name) { return "file://" + Quickshell.shellPath("icons/" + name + ".svg") }
    function openPath(p) {            // folder: show in Trail. file: hand to the desktop.
        trailGoto = p; gotoSerial++; trailVisible = true
    }
    function openFile(p) { Quickshell.execDetached(["xdg-open", p]) }
    function refreshDrives() { drivesProc.running = true; refreshCounts() }
    function refreshCounts() {
        var names = ["Documents", "Downloads", "Pictures", "Music", "Videos"]
        countsProc.command = ["python3", helper, "counts"].concat(names.map(function (n) { return home + "/" + n }))
        countsProc.running = true
    }
    function eject(dev) { if (dev) { ejectProc.command = ["python3", helper, "eject", dev]; ejectProc.running = true } }
    onTrailVisibleChanged: if (!trailVisible) Qt.quit()

    Process {
        id: drivesProc
        command: ["python3", app.helper, "drives"]
        stdout: StdioCollector { onStreamFinished: { try { app.drives = JSON.parse(text) } catch (e) { console.log("TRAIL drives parse error " + e) } } }
    }
    Process {
        id: countsProc
        stdout: StdioCollector { onStreamFinished: { try { app.counts = JSON.parse(text) } catch (e) { console.log("TRAIL counts parse error " + e) } } }
    }
    Process {
        id: ejectProc
        stdout: StdioCollector { onStreamFinished: app.refreshDrives() }
    }
    Timer { interval: 5000; repeat: true; running: app.trailVisible; onTriggered: app.refreshDrives() }
    Component.onCompleted: refreshDrives()

    TrailWindow { app: app }
}
