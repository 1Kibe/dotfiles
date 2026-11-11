pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/wallpaper.js" as Wallpaper

// The wallpaper gallery (Configurações → Papel de parede): the pictures of four
// folders, listed with the same checks as the lock's picker (BackgroundStore:
// regular files only, no link, up to 30 MB, of real type PNG, JPEG or WebP).
// Choosing one from the repo's folder or from the imported ones sets it at
// once; one from Imagens or Capturas is imported first: copied into
// ~/.local/share/dotfiles/wallpapers (700, outside the repo:
// ~/.config/wallpapers is the repo's own folder, by stow) under a name made
// from its content, never its own name. The copy is checked again (size and
// real type) before it gets its name.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string repoDir: `${home}/.config/wallpapers`
    readonly property string importDir: `${home}/.local/share/dotfiles/wallpapers`
    readonly property var tabs: [
        { id: "repo", label: "Do repo", dir: repoDir },
        { id: "imported", label: "Importadas", dir: importDir },
        { id: "pictures", label: "Imagens", dir: BackgroundStore.picturesDir },
        { id: "captures", label: "Capturas", dir: `${BackgroundStore.picturesDir}/Capturas` }
    ]

    property string tab: "repo"
    property var files: []
    property bool busy: false
    property string message: ""

    function showTab(id) {
        const t = tabs.find(x => x.id === id) ?? tabs[0]
        tab = t.id
        files = []
        run(["sh", "-c", BackgroundStore.listScript, "sh", t.dir, String(BackgroundStore.maxBytes)], (code, out) => {
            if (root.tab === t.id)
                root.files = out.split("\n").filter(f => f !== "")
        })
    }

    // "~/..." for a path under the home (the setting stays portable)
    function portable(path) {
        return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path
    }

    // A picture of the gallery (a path it listed)
    function choose(path) {
        if (busy || typeof path !== "string" || !path.startsWith("/") || path.includes("\n"))
            return
        message = ""
        const dir = path.slice(0, path.lastIndexOf("/"))
        if (dir === repoDir || dir === importDir) {
            if (!SettingsStore.set("wallpaper", portable(path)))
                message = "Não deu para usar essa imagem"
            return
        }
        busy = true
        // 30 s at most, so `busy` never stays on
        run(["timeout", "30", "sh", "-c", importScript, "sh", path, importDir, String(BackgroundStore.maxBytes)], (code, out) => {
            root.busy = false
            const dest = out.trim()
            if (code !== 0 || !dest.startsWith(root.importDir + "/") || dest.includes("\n")) {
                root.message = "Não deu para importar essa imagem"
                return
            }
            if (!SettingsStore.set("wallpaper", root.portable(dest)))
                root.message = "Não deu para usar essa imagem"
            if (root.tab === "imported")
                root.showTab("imported")
        })
    }

    // The import itself (settings/wallpaper.js)
    readonly property string importScript: Wallpaper.importScript

    // ── Commands (argument lists only) ──
    component Job: Process {
        property var done: null
        property bool finished: false
        stdout: StdioCollector {
            id: out
        }
        function finish(code, text) {
            if (finished)
                return
            finished = true
            if (done)
                done(code, text)
            destroy()
        }
        onExited: code => finish(code, out.text)
        onRunningChanged: {
            if (!running && !finished)
                Qt.callLater(() => finish(-1, ""))
        }
    }
    Component {
        id: jobComponent
        Job {}
    }
    function run(command, done) {
        const job = jobComponent.createObject(root, { command: command, done: done || null })
        job.running = true
    }
}
