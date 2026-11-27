// Arabic and English strings (i18n.json), picked by Settings.language.
// t(key) falls back to English, then to the key itself, so a missing string never breaks a page.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var strings: ({})

    readonly property string lang: Settings.language === "ar" ? "ar" : "en"
    readonly property bool rtl: lang === "ar"

    function t(key) {
        var l = root.strings[root.lang] || {}
        var e = root.strings["en"] || {}
        return l[key] !== undefined ? l[key] : (e[key] !== undefined ? e[key] : key)
    }

    FileView {
        path: Quickshell.shellPath("i18n.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.strings = JSON.parse(text()) } catch (e) { console.log("ELTOCONTROL i18n parse error " + e) } }
    }
}
