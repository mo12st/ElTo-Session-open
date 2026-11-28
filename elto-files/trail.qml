// Trail: ElTo file browser (v1) and the "This computer" page, as standalone Quickshell windows.
// Run: quickshell -p elto-files/trail.qml
// Start page: TRAIL_START=computer (This computer page) | an absolute folder path | (unset: home folder).
// v1 scope: browse, open (gio open), sidebar, breadcrumb, back/forward, drive cards with Eject.
// File operations (copy, move, delete, network) come later through KDE KIO, not copied Dolphin code.
// Theme: every colour, radius and font comes from the ElTo theme tokens (themes/soft-paper/theme.json + the user overlay
// ~/.config/elto/theme.json, watched, so a theme or world switch restyles Trail live). No hex in the QML.
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
        function role(r) { var n = roles[r]; return colors[n] !== undefined ? colors[n] : (colors[r] !== undefined ? colors[r] : "transparent") }
        readonly property color surface: role("surface")
        readonly property color surfaceAlt: role("surfaceAlt")
        readonly property color text: role("text")
        readonly property color textMuted: role("textMuted")
        readonly property color accent: role("accent")
        readonly property color selection: role("selection")
        readonly property color divider: role("divider")
        readonly property int radiusWindow: shapeT.radiusWindow !== undefined ? shapeT.radiusWindow : 22
        // Readable colour on top of `selection`, derived from the selection luminance (no schema token for it yet).
        function lum(c) { return c.r * 0.299 + c.g * 0.587 + c.b * 0.114 }
        function onSel() { return lum(selection) < 0.5 ? Qt.lighter(surface, 1.8) : text }
        // Folder colour for era folder art: the world colour named folder, else the accent.
        readonly property color folderYellow: colors.folder !== undefined ? colors.folder : accent
        // Glossy band colours for band-style worlds, derived from the selection hue.
        readonly property color bandTop: Qt.hsla(selection.hslHue, Math.min(1, selection.hslSaturation * 1.3), 0.52, 1)
        readonly property color bandBottom: Qt.hsla(selection.hslHue, Math.min(1, selection.hslSaturation * 1.3), 0.34, 1)
        readonly property color disabled: role("disabled")
        readonly property int radiusPill: shapeT.radiusPill !== undefined ? shapeT.radiusPill : 999
        readonly property int radiusCard: shapeT.radiusCard !== undefined ? shapeT.radiusCard : 14
        // Optional structural tokens (all in `shape`, so world apply carries them). Defaults keep the soft-paper look.
        readonly property int bevel: typeof shapeT.bevel === "number" ? Math.max(0, Math.min(3, Math.round(shapeT.bevel))) : 0
        readonly property bool glass: shapeT.glass === true || (typeof shapeT.glass === "number" && shapeT.glass > 0)
        readonly property bool gloss: shapeT.bevel === "rounded-gloss"
        readonly property real surfaceAlpha: typeof shapeT.surfaceAlpha === "number" ? Math.max(0.3, Math.min(1, shapeT.surfaceAlpha)) : 1
        readonly property string folderArt: ["manila", "flat", "outline", "glass", "classic95", "aero", "luna", "chrome"].indexOf(shapeT.folderArt) >= 0 ? shapeT.folderArt : (cardKey === "band" ? "luna" : "manila")
        // Accepts the world file vocabulary "gloss-band" as well as the internal name "band".
        readonly property string cardKey: shapeT.cardArt === "gloss-band" ? "band" : (shapeT.cardArt || "")
        readonly property string cardArt: ["paper", "w95", "vapor", "aero", "pearl", "chrome", "term", "plain", "band"].indexOf(cardKey) >= 0 ? cardKey
            : ({ classic95: "w95", aero: "aero", luna: "pearl", chrome: "chrome" })[folderArt] || (folderArt === "outline" ? (iconArt === "ascii" ? "term" : "plain") : "paper")
        readonly property string pageKey: shapeT.pageLayout === "desktop-icons" ? "desktop" : (shapeT.pageLayout || "")
        readonly property string pageLayout: ["cards", "grid", "rows", "tiles", "gauge", "table", "columns", "windows", "desktop"].indexOf(pageKey) >= 0 ? pageKey
            : ({ band: "desktop", w95: "grid", vapor: "windows", aero: "rows", pearl: "tiles", chrome: "gauge", term: "table", plain: "columns" })[cardArt] || "cards"
        readonly property string folderView: ["icons", "list", "details", "content", "tiles", "cards", "ls", "names"].indexOf(shapeT.folderView) >= 0 ? shapeT.folderView
            : ({ band: "tiles", w95: "list", vapor: "details", aero: "content", pearl: "tiles", chrome: "cards", term: "ls", plain: "names" })[cardArt] || "icons"
        readonly property string iconArt: ["line", "thin", "bold", "pixel", "gloss", "ascii"].indexOf(shapeT.iconArt) >= 0 ? shapeT.iconArt : (cardKey === "band" ? "gloss" : "line")
        readonly property string mono: fonts.mono || "DejaVu Sans Mono"
        readonly property string snailStyle: ["solid", "outline", "pixel", "glass"].indexOf(shapeT.snail) >= 0 ? shapeT.snail : "solid"
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
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { th.user = JSON.parse(text()) } catch (e) { console.log("TRAIL user theme parse error " + e) } }
        onLoadFailed: th.user = ({})
    }
    readonly property var theme: th

    // ---- actions used by both windows ----
    function openPath(p) {            // folder: show in Trail. file: hand to the desktop.
        trailGoto = p; gotoSerial++; trailVisible = true
    }
    function openFile(p) { Quickshell.execDetached(["gio", "open", p]) }
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
