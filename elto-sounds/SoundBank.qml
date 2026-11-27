// One reusable SoundEffect per call; QtMultimedia import lives only here so Sound.qml survives its absence.
import QtQuick
import QtMultimedia

Item {
    SoundEffect { id: fx }
    function fire(id, url, vol) {
        fx.source = url
        fx.volume = vol
        if (fx.status === SoundEffect.Error) { console.log("ELTOSOUND missing or unreadable " + url); return }
        fx.play()
    }
}
