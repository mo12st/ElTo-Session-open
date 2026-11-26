// Runs shell commands from the greeter via the plasma5support "executable" engine (a KDE library, not plasma-workspace).
// Loaded through a Loader so a missing module only disables media + power buttons, not the unlock field.
import QtQuick
import org.kde.plasma.plasma5support as P5Support

P5Support.DataSource {
    id: ds
    engine: "executable"
    connectedSources: []
    property var handlers: ({})
    onNewData: function (source, data) {
        disconnectSource(source)
        var h = handlers[source]
        delete handlers[source]
        if (h) h((data["stdout"] || "").trim(), data["exit code"])
    }
    function run(cmd, cb) {
        if (cb) handlers[cmd] = cb
        connectSource(cmd)
    }
}
