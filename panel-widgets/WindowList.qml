// CONCEPT / SPIKE window list model fed by the elto-windowlist helper (JSON lines on stdout).
// KWin has no foreign-toplevel, so Quickshell's ToplevelManager stays empty there; this replaces it.
// Roles: uuid, title, appid, isActive.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    property string helper: Quickshell.env("ELTO_WINDOWLIST") || "/tmp/elto-windowlist"
    readonly property alias model: lm
    property bool enabled: true
    // True while any listed window is fullscreen (org_kde_plasma_window state bit 8). Used by Notch.
    property bool fullscreenActive: false
    function recomputeFullscreen() {
        for (let i = 0; i < lm.count; i++)
            if (lm.get(i).isFullscreen) { fullscreenActive = true; return; }
        fullscreenActive = false;
    }

    ListModel { id: lm }

    function indexOf(u) {
        for (let i = 0; i < lm.count; i++)
            if (lm.get(i).uuid === u) return i;
        return -1;
    }
    function activate(u) { wl.write("activate " + u + "\n"); }

    function handle(line) {
        let m;
        try { m = JSON.parse(line); } catch (e) { return; }
        const i = indexOf(m.uuid);
        if (m.event === "add") {
            if (i < 0) lm.append({ uuid: m.uuid, title: "", appid: "", isActive: false, isFullscreen: false });
        } else if (i < 0) {
            return;
        } else if (m.event === "close") {
            lm.remove(i);
            recomputeFullscreen();
        } else if (m.event === "title") {
            lm.setProperty(i, "title", m.title);
        } else if (m.event === "appid") {
            lm.setProperty(i, "appid", m.appid);
        } else if (m.event === "state") {
            lm.setProperty(i, "isActive", (m.flags & 1) !== 0);
            lm.setProperty(i, "isFullscreen", (m.flags & 8) !== 0);
            recomputeFullscreen();
        }
    }

    Process {
        id: wl
        running: root.enabled
        command: [root.helper]
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.handle(data) }
    }
}
