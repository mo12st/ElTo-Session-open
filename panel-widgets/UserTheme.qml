// Writes one value into the user theme overlay (~/.config/elto/theme.json). The shell watches that file, so changes apply live.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    Process { id: writer }
    // Applies a whole theme (name, colors, roles, shape, fonts) on top of the user overlay. Options, dock and wallpaper stay as they are.
    function apply(t) {
        var u = JSON.parse(JSON.stringify(Theme.user))
        var secs = ["colors", "roles", "shape", "fonts"]
        for (var i = 0; i < secs.length; i++) if (t[secs[i]]) u[secs[i]] = JSON.parse(JSON.stringify(t[secs[i]]))
        u.name = t.name
        write(u)
        console.log("ELTOUSER apply theme " + t.name)
    }
    function set(section, key, value) {
        var u = JSON.parse(JSON.stringify(Theme.user))
        if (!u[section]) u[section] = {}
        u[section][key] = value
        write(u)
        console.log("ELTOUSER set " + section + "." + key + "=" + JSON.stringify(value))
    }
    function write(u) {
        var dir = Theme.userPath.substring(0, Theme.userPath.lastIndexOf("/"))
        writer.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", dir, JSON.stringify(u, null, 2), Theme.userPath]
        writer.running = true
    }
}
