// ElTo Control settings store: ~/.config/elto/control.json. Watched, so changes apply live.
// Same pattern as panel-widgets/UserTheme.qml, separate file so Control never mixes its
// state into the theme overlay.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var data: ({})

    readonly property string path: Quickshell.env("HOME") + "/.config/elto/control.json"
    readonly property string language: data.language || "en"

    Process { id: writer }

    function set(key, value) {
        var u = JSON.parse(JSON.stringify(root.data))
        u[key] = value
        var dir = root.path.substring(0, root.path.lastIndexOf("/"))
        writer.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", dir, JSON.stringify(u, null, 2), root.path]
        writer.running = true
        console.log("ELTOCONTROL set " + key + "=" + JSON.stringify(value))
    }

    FileView {
        path: root.path
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()) } catch (e) { root.data = ({}) } }
        onLoadFailed: root.data = ({})
    }
}
