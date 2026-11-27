// ElTo shell sounds (CONCEPT until the implementer's VM run). Sound.play("notification") etc.
// In-process Qt Multimedia SoundEffect, no process per event. Gate: overlay `sounds.enabled` (default false).
// Theme dir: ~/.local/share/sounds/<overlay _world.id>/stereo/<event>.wav, installed by elto-world. Missing dir/file/module = silent skip.
// Events: session-start, session-end, notification, drawer-open, drawer-close, lock, unlock (real shell events only).
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    readonly property var cfg: Theme.user.sounds || ({})
    readonly property bool enabled: cfg.enabled === true
    readonly property string worldId: (Theme.user._world && typeof Theme.user._world.id === "string" && /^[a-z0-9][a-z0-9-]*$/.test(Theme.user._world.id)) ? Theme.user._world.id : ""
    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/sounds/" + worldId + "/stereo/"
    readonly property var events: ["session-start", "session-end", "notification", "drawer-open", "drawer-close", "lock", "unlock"]
    property var last: ({})
    property bool startPending: false
    property double pendingUntil: 0
    // The overlay loads asynchronously: a start event that arrives before it is held until the gate and world id are known.
    onEnabledChanged: flushStart()
    onWorldIdChanged: flushStart()
    function flushStart() {
        if (startPending && Date.now() > pendingUntil) startPending = false
        if (startPending && enabled && worldId !== "") { startPending = false; play("session-start") }
    }

    function play(ev) {
        if (events.indexOf(ev) < 0) return
        var now = Date.now()
        if (ev === "session-start" && (!enabled || worldId === "")) { startPending = true; pendingUntil = now + 5000; return }
        if (!enabled || worldId === "") return
        if (last[ev] && now - last[ev] < 150) return   // same event at most every 150 ms
        last[ev] = now
        console.log("ELTOSOUND fire " + ev + " world=" + worldId)
        if (loader.item) loader.item.fire(ev, "file://" + dir + ev + ".wav")
    }

    // QtMultimedia lives only in SoundBank, so its absence disables sounds, never the shell.
    Loader {
        id: loader
        source: Qt.resolvedUrl("SoundBank.qml")
        onStatusChanged: if (status === Loader.Error) console.log("ELTOSOUND QtMultimedia unavailable, sounds off")
    }
}
