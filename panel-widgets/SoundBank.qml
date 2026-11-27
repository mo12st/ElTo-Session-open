// One SoundEffect per event id, created on first use and reused. Missing file: logged once, skipped.
import QtQuick
import QtMultimedia

Item {
    id: bank
    property var fx: ({})
    Component {
        id: maker
        SoundEffect { volume: 0.7 }
    }
    function fire(ev, url) {
        var e = fx[ev]
        if (!e || e.source.toString() !== url) {
            e = maker.createObject(bank, { source: url })
            fx[ev] = e
        }
        if (e.status === SoundEffect.Error) { console.log("ELTOSOUND missing or unreadable " + ev); return }
        e.play()
    }
}
