// Theme singleton: the single source for colors, shapes, fonts and style options. No hex in QML.
// Reads themes/soft-paper/theme.json (shipped default, always loaded) and overlays ~/.config/elto/theme.json
// (or $ELTO_THEME) on top. The user file is watched, so edits restyle the shell live. Missing tokens fall back to the default.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var base: ({})
    property var user: ({})
    readonly property string userPath: Quickshell.env("ELTO_THEME") || (Quickshell.env("HOME") + "/.config/elto/theme.json")

    function section(name) {
        var out = {}, b = root.base[name] || {}, u = root.user[name] || {}
        for (var k in b) out[k] = b[k]
        for (var j in u) out[j] = u[j]
        return out
    }
    readonly property var colorsT: section("colors")
    readonly property var rolesT: section("roles")
    readonly property var shapeT: section("shape")
    readonly property var fontsT: section("fonts")
    readonly property var optionsT: section("options")
    readonly property var notchT: section("notch")

    function role(r) { var n = rolesT[r]; return colorsT[n] !== undefined ? colorsT[n] : (colorsT[r] !== undefined ? colorsT[r] : "transparent") }
    function color(name) { return colorsT[name] !== undefined ? colorsT[name] : "transparent" }

    readonly property string name: (user.name || base.name || "")
    readonly property color surface: role("surface")
    readonly property color surfaceAlt: role("surfaceAlt")
    readonly property color text: role("text")
    readonly property color textMuted: role("textMuted")
    readonly property color accent: role("accent")
    readonly property color selection: role("selection")
    readonly property color divider: role("divider")
    readonly property color disabled: role("disabled")

    readonly property int radiusWindow: shapeT.radiusWindow
    readonly property int radiusCard: shapeT.radiusCard
    readonly property real shadowAlpha: shapeT.shadowAlpha
    readonly property int shadowBlur: shapeT.shadowBlur
    readonly property int shadowOffsetY: shapeT.shadowOffsetY

    readonly property string serif: fontsT.serif
    readonly property string serifItalic: fontsT.serifItalic
    readonly property string sans: fontsT.sans
    readonly property string mono: fontsT.mono

    readonly property string dockStyle: optionsT.dock
    readonly property string wallpaper: optionsT.wallpaper
    readonly property bool motion: optionsT.motion !== "off"
    function ms(v) { return motion ? v : 0 }

    FileView {
        path: Quickshell.shellPath("../themes/soft-paper/theme.json")
        blockLoading: true
        onLoaded: { try { root.base = JSON.parse(text()) } catch (e) { console.log("ELTOTHEME base parse error " + e) } }
    }
    FileView {
        path: root.userPath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.user = JSON.parse(text()); console.log("ELTOTHEME user theme loaded: " + root.name) } catch (e) { console.log("ELTOTHEME user parse error " + e) } }
        onLoadFailed: root.user = ({})
    }
}
