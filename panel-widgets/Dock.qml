// ElTo dock (CONCEPT until approved). Logic only: pinned apps (from the theme overlay), running windows,
// pin/unpin, launching, and which variant draws it. The variant comes from options.dock and is resolved
// through DockStyle.qml: island draws DockWindow.qml, bar draws DockBar.qml, anything unknown or still a
// concept falls back to island. Each *Blur.qml file is the same variant plus a compositor blur request.
// See DOCK-VARIANTS.md.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root
    readonly property var dk: Theme.dockT
    // icon folder for the pinned glyphs: "lucide" (white line glyphs, tinted) or a vendored multi-colour set
    // under icons/. glyphTint false draws the files as they are. Both are theme keys, so a swap is one line.
    readonly property string glyphDir: root.dk.glyphDir || "lucide"
    readonly property bool glyphTint: root.dk.glyphTint !== false

    // ---- per-world dock identity. Every token below is optional in the theme; a world that omits them draws
    // exactly what the shell drew before they existed. An unknown value falls back to the default, never to a
    // broken dock, the same way an unknown options.dock falls back to island.
    function pick(v, list, def) { return list.indexOf(v) >= 0 ? v : def }
    function num(v, def) { return (typeof v === "number" && v > 0) ? Math.round(v) : def }
    readonly property var look: {
        var d = root.dk
        return {
            material: root.pick(d.dockMaterial, ["paper", "flat", "glass", "gloss", "bevel"], "paper"),
            radius: root.num(d.dockRadius, d.radius),
            height: root.num(d.dockHeight, d.height),
            button: root.pick(d.dockButton, ["circle", "rounded", "square"], "circle"),
            launcherMark: root.pick(d.launcherMark, ["none", "dot", "label", "button"], "none"),
            launcherLabel: typeof d.launcherLabel === "string" ? d.launcherLabel : "ElTo",
            clockStyle: root.pick(d.clockStyle, ["text", "pill", "none"], "text"),
            clockPosition: root.pick(d.clockPosition, ["end", "start"], "end"),
            trayStyle: root.pick(d.trayStyle, ["text", "compact", "none"], "text"),
            activeIndicator: root.pick(d.activeIndicator, ["pill", "dot", "bar", "none"], "pill"),
            taskStyle: root.pick(d.taskStyle, ["pill", "button", "label"], "pill"),
            edge: root.pick(d.edge, ["bottom", "top"], "bottom")
        }
    }
    property string activeApp: ""
    // set by elto-shell so the launcher button can open the app drawer, the same way Notch takes one
    property var drawer: null
    property var openApps: ({})
    property bool blurBroken: false

    // Pinned ids are reverse-DNS on some distros (org.mozilla.firefox) and plain on others (firefox), so an exact
    // byId miss falls back to the last segment of the id, then to the app name. Without this a pinned app that is
    // installed still drops out of the dock and its slot disappears.
    function pinnedEntry(id) {
        var e = DesktopEntries.byId(id)
        if (e) return e
        var short = String(id).toLowerCase().split(".").pop()
        var vals = DesktopEntries.applications.values
        for (var i = 0; i < vals.length; i++) {
            var vid = String(vals[i].id || "").toLowerCase()
            if (vid === short || vid === short + ".desktop" || vid.split(".").pop() === short) return vals[i]
        }
        for (var j = 0; j < vals.length; j++) {
            if (String(vals[j].name || "").toLowerCase() === short) return vals[j]
        }
        return null
    }

    // ---- pinned apps: ids of desktop entries, kept in dock.pinned of the user theme. Entries that are not installed are skipped.
    readonly property var pinnedItems: {
        var n = DesktopEntries.applications.values.length   // re-evaluate when entries finish loading
        var out = []
        var ids = root.dk.pinned || []
        for (var i = 0; i < ids.length; i++) {
            var e = root.pinnedEntry(ids[i])
            if (e) out.push({ id: ids[i], entry: e, glyph: (root.dk.glyphs || {})[ids[i]] || "" })
        }
        return out
    }
    function isPinned(id) { return (root.dk.pinned || []).indexOf(id) >= 0 }
    function pin(id) { if (!isPinned(id)) UserTheme.set("dock", "pinned", (root.dk.pinned || []).concat([id])) }
    function unpin(id) { UserTheme.set("dock", "pinned", (root.dk.pinned || []).filter(x => x !== id)) }
    function entryFor(appid) { return DesktopEntries.byId(appid) || DesktopEntries.heuristicLookup(appid) }

    WindowList { id: wl; Component.onCompleted: root.wl = wl }
    property var wl: null
    function refresh() {
        var o = {}, act = ""
        for (var i = 0; i < wl.model.count; i++) {
            var w = wl.model.get(i)
            o[w.appid] = true
            if (w.isActive) act = w.appid
        }
        root.openApps = o; root.activeApp = act
    }
    Connections { target: wl.model; function onCountChanged() { root.refresh() } function onDataChanged() { root.refresh() } }

    // ---- variant: options.dock resolved through the registry, so an unknown or still-concept id always
    // lands on island and the session always has a dock.
    readonly property string style: DockStyle.resolve(Theme.dockStyle)
    // one log line per resolution, so the dock smoke test can prove which variant was chosen
    Component.onCompleted: console.log("ELTODOCK variant " + root.style)
    onStyleChanged: console.log("ELTODOCK variant " + root.style)

    Variants {
        model: Quickshell.screens
        Loader {
            id: ld
            required property var modelData
            function load() {
                var blurred = root.dk.blur && !root.blurBroken ? DockStyle.blurFor(root.style) : ""
                ld.setSource(blurred !== "" ? blurred : DockStyle.windowFor(root.style), { dock: root, screen: ld.modelData })
            }
            Component.onCompleted: load()
            Connections { target: Theme; function onDockTChanged() { ld.load() } }
            Connections { target: root; function onStyleChanged() { ld.load() } }
            onStatusChanged: if (status === Loader.Error && !root.blurBroken && root.dk.blur) {
                root.blurBroken = true; console.log("ELTODOCKBLUR unsupported, plain dock"); ld.load() }
        }
    }
}
