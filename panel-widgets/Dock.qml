// ElTo bottom island dock (CONCEPT until approved). Logic only: pinned apps (from the theme overlay), running windows,
// pin/unpin, launching. The window is DockWindow.qml (DockWindowBlur.qml adds a compositor blur request).
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

    Variants {
        model: Quickshell.screens
        Loader {
            id: ld
            required property var modelData
            Component.onCompleted: setSource(Theme.dockT.blur && !root.blurBroken ? "DockWindowBlur.qml" : "DockWindow.qml", { dock: root, screen: modelData })
            Connections { target: Theme; function onDockTChanged() {
                ld.setSource(Theme.dockT.blur && !root.blurBroken ? "DockWindowBlur.qml" : "DockWindow.qml", { dock: root, screen: ld.modelData }) } }
            onStatusChanged: if (status === Loader.Error && !root.blurBroken) { root.blurBroken = true; console.log("ELTODOCKBLUR unsupported, plain dock") }
        }
    }
}
