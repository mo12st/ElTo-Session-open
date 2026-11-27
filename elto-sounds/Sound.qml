// ElTo shell sounds (CONCEPT until VM-run by the implementer). Singleton: Sound.play("elto-drawer-open").
// No external process per event: QtMultimedia SoundEffect objects are created once and reused.
// Loaded via Loader, so a missing QtMultimedia only disables sounds, never the shell.
// Off by default. Settings live in the user theme overlay: options.sounds = { enabled, theme, volume }.
// Events fire only from real shell events (see hooks/README.md). Files: ~/.local/share/sounds/<theme>/stereo/<id>.wav
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    readonly property var cfg: Theme.optionsT.sounds || ({})
    readonly property bool enabled: cfg.enabled === true
    readonly property string themeName: (typeof cfg.theme === "string" && /^[A-Za-z0-9_-]+$/.test(cfg.theme)) ? cfg.theme : "elto-soft"
    readonly property real volume: Math.max(0, Math.min(1, typeof cfg.volume === "number" ? cfg.volume : 0.6))
    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/sounds/" + themeName + "/stereo/"
    readonly property var events: ["message-new-instant", "elto-drawer-open", "elto-drawer-close", "elto-lock", "elto-unlock", "desktop-login"]
    property var lastPlayed: ({})
    property string lastEvent: ""

    // Missing file or module: silent no-op. Same event is rate-limited to once per 150 ms.
    function play(id) {
        if (!enabled || events.indexOf(id) < 0) return
        var now = Date.now()
        if (lastPlayed[id] && now - lastPlayed[id] < 150) return
        lastPlayed[id] = now
        lastEvent = id
        console.log("ELTOSOUND fire " + id)
        var o = loader.item
        if (o) o.fire(id, "file://" + dir + id + ".wav", volume)
    }

    Loader {
        id: loader
        source: Qt.resolvedUrl("SoundBank.qml")
        onStatusChanged: if (status === Loader.Error) console.log("ELTOSOUND QtMultimedia unavailable, sounds disabled")
    }
}
