// Themes page for Customize (CONCEPT until approved). List, edit a copy, apply, export, install.
// All file work goes through theme-tool.py, which only reads, validates and copies theme.json (no package code runs).
// Colors and shape edits write a user theme under ~/.config/elto/themes/<slug>/. Apply puts the theme on the live overlay.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: pg
    property var themes: []
    property int sel: -1
    property var draft: null
    property string draftSlug: ""
    property bool draftBuiltin: true
    property string status: ""
    property bool installOpen: false
    property string pendingSlug: ""
    readonly property string tool: Quickshell.shellPath("theme-tool.py")
    readonly property var roleRows: [
        { r: "surface", l: "Surface" }, { r: "surfaceAlt", l: "Surface alt" },
        { r: "text", l: "Text" }, { r: "textMuted", l: "Muted text" },
        { r: "selection", l: "Selection" }, { r: "accent", l: "Accent" }
    ]

    function clone(o) { return JSON.parse(JSON.stringify(o)) }
    function dc(role) { return pg.draft ? (pg.draft.colors[pg.draft.roles[role]] || "#000000") : "#000000" }
    function labelOf(t) { return t.label || t.name }
    function slugify(s) { var r = String(s).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); return r.substring(0, 40) || "theme" }

    function refresh() { lister.running = true }
    function select(i) {
        if (i < 0 || i >= pg.themes.length) return
        pg.sel = i; pg.draft = clone(pg.themes[i].theme); pg.draftSlug = pg.themes[i].slug; pg.draftBuiltin = pg.themes[i].builtin
    }
    function selectSlug(slug) { for (var i = 0; i < pg.themes.length; i++) if (pg.themes[i].slug === slug) { select(i); return } }
    function runTool(args, stdinText, done) {
        runner.done = done
        runner.command = ["sh", "-c", "if [ -n \"$2\" ]; then printf '%s' \"$2\" | python3 \"$1\" $3 \"$4\"; else python3 \"$1\" $3 \"$4\"; fi",
                          "sh", pg.tool, stdinText || "", args[0], args[1] || ""]
        runner.running = true
    }
    function persist() {   // save the draft back to its user theme file
        if (!pg.draft || pg.draftBuiltin) return
        runTool(["save", pg.draftSlug], JSON.stringify(pg.draft), function (o) { if (!o.ok) pg.status = "Could not save: " + o.error })
    }
    function newFromCopy() {
        if (!pg.draft) return
        var d = clone(pg.draft), n = "My theme", k = 2, names = pg.themes.map(function (t) { return t.theme.name })
        while (names.indexOf(n) >= 0) { n = "My theme " + k; k++ }
        d.name = n; delete d.label
        var slug = slugify(n)
        pg.pendingSlug = slug
        runTool(["save", slug], JSON.stringify(d), function (o) { if (o.ok) { pg.status = "Created " + n; refresh() } else pg.status = "Could not create: " + o.error })
    }
    function setColor(role, hex) {
        if (pg.draftBuiltin || !/^#[0-9a-fA-F]{6}$/.test(hex)) return
        var d = clone(pg.draft), key = "my" + role.charAt(0).toUpperCase() + role.slice(1)
        d.colors[key] = hex.toLowerCase(); d.roles[role] = key
        pg.draft = d; persist()
    }
    function setShape(key, v) {
        if (pg.draftBuiltin) return
        var d = clone(pg.draft); if (!d.shape) d.shape = {}
        d.shape[key] = v; pg.draft = d; persist()
    }
    function rename(n) {
        n = n.trim(); if (pg.draftBuiltin || n === "" || n === pg.draft.name) return
        var d = clone(pg.draft); d.name = n; pg.draft = d; persist()
        pg.themes[pg.sel].theme.name = n; pg.themes = pg.themes.slice()
    }
    function doApply() { if (pg.draft) { UserTheme.apply(pg.draft); pg.status = "Applied " + pg.draft.name } }
    function doExport() {
        if (pg.draftBuiltin) { pg.status = "Built-in themes are read-only. Make a copy first."; return }
        runTool(["export", pg.draftSlug], "", function (o) { pg.status = o.ok ? "Exported to " + o.path : "Export failed: " + o.error })
    }
    function doInstall(path) {
        path = path.replace(/^file:\/\//, "").trim()
        if (path === "") return
        runTool(["install", path], "", function (o) { if (o.ok) { pg.status = "Installed " + o.name; pg.pendingSlug = o.slug; pg.installOpen = false; refresh() } else pg.status = "Install failed: " + o.error })
    }

    Process {
        id: lister
        command: ["python3", pg.tool, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.themes = JSON.parse(text) } catch (e) { pg.themes = []; pg.status = "Could not read themes" }
                if (pg.pendingSlug !== "") { pg.selectSlug(pg.pendingSlug); pg.pendingSlug = "" }
                else {
                    var keep = pg.draftSlug
                    if (keep !== "") pg.selectSlug(keep)
                    if (pg.sel < 0 || pg.draftSlug === "") {
                        for (var i = 0; i < pg.themes.length; i++) if (pg.themes[i].theme.name === Theme.name) { pg.select(i); break }
                        if (pg.sel < 0) pg.select(0)
                    }
                }
                console.log("ELTOTHEMES listed " + pg.themes.length)
            }
        }
    }
    Process {
        id: runner
        property var done: null
        stdout: StdioCollector {
            onStreamFinished: {
                var o = { ok: false, error: "no answer" }
                try { o = JSON.parse(text) } catch (e) {}
                console.log("ELTOTHEMES tool " + (o.ok ? "ok" : "error: " + o.error))
                if (runner.done) runner.done(o)
            }
        }
    }
    Component.onCompleted: refresh()

    // ---------- header
    Text { x: 28; y: 22; text: "Themes"; color: Theme.text; font.family: Theme.serif; font.pixelSize: 38; renderType: Text.NativeRendering }
    Text { anchors.right: parent.right; anchors.rightMargin: 30; y: 40; text: pg.status
        color: Theme.textMuted; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 14; renderType: Text.NativeRendering
        width: 560; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }

    // ---------- left: actions + list
    Row {
        x: 28; y: 84; spacing: 8
        PillBtn { label: "Install"; onClicked: pg.installOpen = !pg.installOpen }
        PillBtn { label: "New from copy"; onClicked: pg.newFromCopy() }
    }
    Column {
        x: 28; y: 134; width: 300; spacing: 8
        Repeater {
            model: pg.themes
            Rectangle {
                id: row
                required property var modelData
                required property int index
                width: 300; height: 58; radius: Theme.radiusCard
                color: pg.sel === row.index ? Theme.selection : Theme.surfaceAlt
                border.width: Theme.name === row.modelData.theme.name ? 2 : 0; border.color: Theme.accent
                Text { x: 14; y: 8; text: pg.labelOf(row.modelData.theme); color: Theme.text; font.family: Theme.sans; font.pixelSize: 15; width: 150; elide: Text.ElideRight }
                Text { x: 14; y: 32; text: row.modelData.builtin ? "Built-in" : "Yours"; color: Theme.textMuted; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 12 }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                    Repeater {
                        model: ["surface", "selection", "textMuted", "text", "accent"]
                        Rectangle { required property string modelData; width: 18; height: 18; radius: 9; border.width: 1; border.color: Theme.divider
                            color: row.modelData.theme.colors[row.modelData.theme.roles[modelData]] || "transparent" }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: pg.select(row.index) }
            }
        }
    }

    // ---------- install panel
    Rectangle {
        visible: pg.installOpen
        x: 28; y: 134; width: 360; height: 168; radius: Theme.radiusCard; z: 5
        color: Theme.surface; border.width: 1; border.color: Theme.divider
        Text { x: 18; y: 12; text: "Install theme"; color: Theme.text; font.family: Theme.serif; font.pixelSize: 22; renderType: Text.NativeRendering }
        Rectangle {
            id: drop
            x: 18; y: 50; width: parent.width - 36; height: 52; radius: 10; color: Theme.surfaceAlt
            border.width: dz.containsDrag ? 2 : 1; border.color: dz.containsDrag ? Theme.accent : Theme.divider
            Text { anchors.centerIn: parent; text: "Drop a theme folder or .zip here"; color: Theme.textMuted; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 14 }
            DropArea { id: dz; anchors.fill: parent
                onDropped: d => { if (d.hasUrls) pg.doInstall(d.urls[0].toString()) } }
        }
        Rectangle {
            x: 18; y: 112; width: parent.width - 36 - 76; height: 36; radius: 18; color: Theme.surfaceAlt
            TextInput {
                id: pathIn
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.sans; font.pixelSize: 13; color: Theme.text; clip: true
                onAccepted: pg.doInstall(text)
            }
            Text { visible: pathIn.text === ""; anchors.fill: pathIn; verticalAlignment: Text.AlignVCenter; text: "or type a path"; color: Theme.disabled; font.family: Theme.sans; font.pixelSize: 13 }
        }
        PillBtn { x: parent.width - 18 - 68; y: 111; label: "Install"; primary: true; onClicked: pg.doInstall(pathIn.text) }
    }

    // ---------- right column
    Item {
        id: rc
        x: 408; y: 84; width: 600; height: parent.height - 100
        visible: pg.draft !== null

        Rectangle {
            width: 330; height: 38; radius: 19; color: Theme.surfaceAlt
            TextInput {
                id: nameIn
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; verticalAlignment: TextInput.AlignVCenter
                text: pg.draft ? pg.labelOf(pg.draft) : ""; readOnly: pg.draftBuiltin; clip: true
                font.family: Theme.serif; font.pixelSize: 18; color: pg.draftBuiltin ? Theme.textMuted : Theme.text
                onEditingFinished: pg.rename(text)
            }
        }
        Row {
            anchors.right: parent.right; spacing: 8
            PillBtn { label: "Export"; onClicked: pg.doExport() }
            PillBtn { label: "Apply"; primary: true; onClicked: pg.doApply() }
        }
        Text { y: 46; text: pg.draftBuiltin ? "Built-in, read-only. Use New from copy to edit." : "Editing saves as you go. Apply to use it."
            color: Theme.textMuted; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 13; renderType: Text.NativeRendering }

        // colors
        Rectangle {
            y: 76; width: parent.width; height: 214; radius: Theme.radiusCard; color: Theme.surfaceAlt
            Text { x: 16; y: 10; text: "Colors"; color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 20; renderType: Text.NativeRendering }
            Grid {
                x: 14; y: 46; columns: 2; spacing: 8
                Repeater {
                    model: pg.roleRows
                    Rectangle {
                        id: cr
                        required property var modelData
                        width: 284; height: 48; radius: 12; color: Theme.surface
                        Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 14; color: pg.dc(cr.modelData.r); border.width: 1; border.color: Theme.divider }
                        Text { x: 48; y: 6; text: cr.modelData.l; color: Theme.text; font.family: Theme.sans; font.pixelSize: 13 }
                        TextInput {
                            x: 48; y: 25; width: 100; maxLength: 7; readOnly: pg.draftBuiltin
                            text: pg.dc(cr.modelData.r); color: pg.draftBuiltin ? Theme.textMuted : Theme.text
                            font.family: Theme.mono; font.pixelSize: 12
                            onEditingFinished: pg.setColor(cr.modelData.r, text)
                        }
                    }
                }
            }
        }

        // shape
        Rectangle {
            y: 302; width: parent.width; height: 118; radius: Theme.radiusCard; color: Theme.surfaceAlt
            Text { x: 16; y: 10; text: "Shape"; color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 20; renderType: Text.NativeRendering }
            Repeater {
                model: [{ k: "radiusCard", l: "Corner radius", lo: 0, hi: 28 }, { k: "shadowAlpha", l: "Shadow", lo: 0, hi: 0.5 }]
                Item {
                    id: sr
                    required property var modelData
                    required property int index
                    x: 16; y: 46 + index * 32; width: parent.width - 32; height: 28
                    readonly property real v: pg.draft && pg.draft.shape && pg.draft.shape[modelData.k] !== undefined ? pg.draft.shape[modelData.k] : modelData.lo
                    readonly property real frac: (v - modelData.lo) / (modelData.hi - modelData.lo)
                    Text { text: sr.modelData.l; anchors.verticalCenter: parent.verticalCenter; color: Theme.text; font.family: Theme.sans; font.pixelSize: 13 }
                    Item {
                        x: 130; width: parent.width - 130; height: parent.height
                        Rectangle { y: 11; width: parent.width; height: 6; radius: 3; color: Theme.surface }
                        Rectangle { y: 11; width: parent.width * sr.frac; height: 6; radius: 3; color: Theme.color("midGreen") }
                        Rectangle { x: parent.width * sr.frac - 7; y: 7; width: 14; height: 14; radius: 7; color: pg.draftBuiltin ? Theme.disabled : Theme.accent }
                        MouseArea {
                            anchors.fill: parent; enabled: !pg.draftBuiltin
                            function put(mx) {
                                var f = Math.max(0, Math.min(1, mx / width)), m = sr.modelData
                                var v = m.lo + f * (m.hi - m.lo)
                                pg.setShape(m.k, m.k === "radiusCard" ? Math.round(v) : Math.round(v * 100) / 100)
                            }
                            onPressed: m => put(m.x)
                            onPositionChanged: m => { if (pressed) put(m.x) }
                        }
                    }
                }
            }
        }

        // live preview (draft colors, not the applied theme)
        Rectangle {
            y: 432; width: parent.width; height: 160; radius: Theme.radiusCard; color: Theme.surfaceAlt
            Text { x: 16; y: 10; text: "Live preview"; color: Theme.text; font.family: Theme.serifItalic; font.italic: true; font.pixelSize: 20; renderType: Text.NativeRendering }
            Rectangle {
                x: 16; y: 46; width: parent.width - 32; height: 100
                radius: pg.draft && pg.draft.shape && pg.draft.shape.radiusCard !== undefined ? pg.draft.shape.radiusCard : 14
                color: pg.dc("surface"); border.width: 1; border.color: pg.dc("textMuted")
                Text { x: 16; y: 10; text: "Apps"; color: pg.dc("text"); font.family: Theme.serif; font.pixelSize: 22 }
                Rectangle { x: 16; y: 46; width: 170; height: 36; radius: parent.radius; color: pg.dc("selection")
                    Text { anchors.centerIn: parent; text: "Selected"; color: pg.dc("text"); font.family: Theme.sans; font.pixelSize: 14 } }
                Rectangle { x: 198; y: 46; width: 170; height: 36; radius: parent.radius; color: pg.dc("surfaceAlt")
                    Text { anchors.centerIn: parent; text: "Muted"; color: pg.dc("textMuted"); font.family: Theme.sans; font.pixelSize: 14 } }
                Rectangle { x: parent.width - 44; y: 52; width: 24; height: 24; radius: 12; color: pg.dc("accent") }
            }
        }
    }
}
