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
    property string activeApp: ""
    property var openApps: ({})
    property bool blurBroken: false

    // ---- pinned apps: ids of desktop entries, kept in dock.pinned of the user theme. Entries that are not installed are skipped.
    readonly property var pinnedItems: {
        var n = DesktopEntries.applications.values.length   // re-evaluate when entries finish loading
        var out = []
        var ids = root.dk.pinned || []
        for (var i = 0; i < ids.length; i++) {
            var e = DesktopEntries.byId(ids[i])
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
