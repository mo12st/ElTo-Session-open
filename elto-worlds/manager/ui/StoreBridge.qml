// Bridge between the manager UI and the data-only backends:
//   store.py --cli ...   (catalog, KDE listings, registry, imports)
//   elto-world ...       (status, apply, reset of worlds)
// One Process, serialized queue: the UI is user-paced, and a single process
// keeps callbacks unambiguous. Every reply is one JSON object on stdout.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: bridge

    // Qt.resolvedUrl inside a QtObject returns the qrc:/qs-blackhole
    // placeholder, not the real file; Quickshell.shellPath resolves
    // against the shell root (the ui/ dir ManagerWindow.qml launches from).
    readonly property string storePath: Quickshell.shellPath("../store.py")
    readonly property string eltoWorld: Quickshell.shellPath("../../elto-world")
    readonly property string worldsDir: Quickshell.shellPath("../../worlds")

    property var queue: []
    property bool busy: false
    // session download log for the Downloads page: {title, state, detail}
    property ListModel history: ListModel {}

    signal statusChanged

    function run(args, cb) {
        queue.push({ args: args, cb: cb })
        if (!busy) _next()
    }
    function _next() {
        if (queue.length === 0) { busy = false; return }
        busy = true
        const job = queue.shift()
        proc._cb = job.cb
        proc.command = job.args
        proc.running = true
    }
    function _store(args, cb) { run(["python3", storePath, "--cli"].concat(args), cb) }

    function worlds(cb) { _store(["worlds"], cb) }
    function kde(category, cb) { _store(["kde", category], cb) }
    function functions(cb) { _store(["functions"], cb) }
    function installed(cb) { _store(["installed"], cb) }
    function setEnabled(key, on, cb) { _store([on ? "enable" : "disable", key], cb) }
    function remove(key, cb) { _store(["remove", key], cb) }
    function status(cb) { run([eltoWorld, "status"], cb) }
    function reset(cb) { run([eltoWorld, "reset"], function (o) { cb(o); statusChanged() }) }

    function installKde(entry) {
        history.append({ title: entry.title || "KDE item", state: "running", detail: "downloading and verifying" })
        _store(["installarg", JSON.stringify(entry)], function (o) {
            const i = history.count - 1
            if (o.ok) history.setProperty(i, "state", "done")
            else { history.setProperty(i, "state", "failed"); history.setProperty(i, "detail", o.error || "failed") }
            statusChanged()
        })
    }
    function applyWorld(id) {
        history.append({ title: "World " + id, state: "running", detail: "applying overlay" })
        run([eltoWorld, "apply", worldsDir + "/" + id], function (o) {
            const i = history.count - 1
            if (o.ok) history.setProperty(i, "state", "done")
            else { history.setProperty(i, "state", "failed"); history.setProperty(i, "detail", o.error || "failed") }
            statusChanged()
        })
    }

    property Process proc: Process {
        property var _cb: null
        stdout: StdioCollector {
            onStreamFinished: {
                let out
                try { out = JSON.parse(text) } catch (e) { out = { ok: false, error: "bad bridge output" } }
                const cb = proc._cb
                proc._cb = null
                if (cb) cb(out)
                bridge._next()
            }
        }
    }
}
