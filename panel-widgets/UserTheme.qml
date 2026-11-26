// Writes one value into the user theme overlay (~/.config/elto/theme.json). The shell watches that file, so changes apply live.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    Process { id: writer }
    function set(section, key, value) {
        var u = JSON.parse(JSON.stringify(Theme.user))
        if (!u[section]) u[section] = {}
        u[section][key] = value
        var dir = Theme.userPath.substring(0, Theme.userPath.lastIndexOf("/"))
        writer.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", dir, JSON.stringify(u, null, 2), Theme.userPath]
        writer.running = true
        console.log("ELTOUSER set " + section + "." + key + "=" + JSON.stringify(value))
    }
}
