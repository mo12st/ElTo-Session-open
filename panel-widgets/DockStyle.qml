// Dock variant registry: the one place that lists the dock styles the shell knows, which of them are
// real (implemented) and which window draws each one.
// options.dock comes from a world file or the user theme, so it is treated as untrusted: every lookup
// goes through resolve(), and an unknown id, an empty value or a variant that is still a concept falls
// back to island. A world can therefore never leave the session without a dock.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property string fallback: "island"

    // id      value a world writes in options.dock
    // label   name the Customize / Control pages show when they list the variants
    // window  the QML file that draws it, relative to panel-widgets/
    // blur    compositor-blur wrapper for the same variant, "" when there is none
    // real    true only when the variant is implemented; concept rows stay listed but resolve to island
    readonly property var variants: [
        { id: "island",        label: "Island",        window: "DockWindow.qml",    blur: "DockWindowBlur.qml", real: true  },
        { id: "bar",           label: "Bar",           window: "DockBar.qml",       blur: "DockBarBlur.qml",    real: true  },
        { id: "rail-dock",     label: "Rail dock",     window: "",                  blur: "",                   real: false },
        { id: "console",       label: "Console",       window: "",                  blur: "",                   real: false },
        { id: "hidden-thread", label: "Hidden thread", window: "",                  blur: "",                   real: false },
        { id: "ridge-shelf",   label: "Ridge shelf",   window: "",                  blur: "",                   real: false }
    ]

    function entry(id) {
        var s = String(id === undefined || id === null ? "" : id).trim().toLowerCase()
        for (var i = 0; i < variants.length; i++) if (variants[i].id === s) return variants[i]
        return null
    }

    function isReal(id) {
        var e = root.entry(id)
        return e !== null && e.real === true
    }

    // last id already warned about, so a bad world file does not spam the log on every re-evaluation
    property string _warned: ""

    // the id the shell actually draws; an unknown or not-yet-implemented id warns once and falls back
    function resolve(id) {
        var raw = String(id === undefined || id === null ? "" : id).trim().toLowerCase()
        if (root.isReal(raw)) return raw
        if (raw !== "" && raw !== root._warned) {
            root._warned = raw
            console.log("ELTODOCK unknown or unsupported dock style '" + raw + "', falling back to " + root.fallback)
        }
        return root.fallback
    }

    function windowFor(id) {
        var e = root.entry(root.resolve(id))
        return e !== null && e.window !== "" ? e.window : "DockWindow.qml"
    }

    function blurFor(id) {
        var e = root.entry(root.resolve(id))
        return e !== null ? e.blur : ""
    }

    // compact list for a picker: [{ id, label, real }]
    function labels() {
        var out = []
        for (var i = 0; i < variants.length; i++)
            out.push({ id: variants[i].id, label: variants[i].label, real: variants[i].real })
        return out
    }
}
