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
        { id: "imported", label: "Meus papéis", dir: importDir },
        { id: "pictures", label: "Pasta Imagens", dir: BackgroundStore.picturesDir },
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

    // A file of the owner's into Meus papéis (Escolher arquivo…, a drop):
    // the same import (real type, size, a regular file, not a link), copied
    // under a name of its own; then Meus papéis shows it. Not used as the
    // wallpaper until it is chosen there. done(ok) when given
    function importFile(path, done) {
        if (busy || typeof path !== "string" || !path.startsWith("/") || path.includes("\n")) {
            if (done)
                done(false)
            return
        }
        message = ""
        busy = true
        run(["timeout", "30", "sh", "-c", importScript, "sh", path, importDir, String(BackgroundStore.maxBytes)], (code, out) => {
            root.busy = false
            const dest = out.trim()
            const ok = code === 0 && dest.startsWith(root.importDir + "/") && !dest.includes("\n")
            if (!ok)
                root.message = "Não deu para importar essa imagem"
            root.showTab("imported")
            if (done)
                done(ok)
        })
    }
    // A file:// URI (the chooser's, a drop's) to a local path, or "" (a
    // remote one, another scheme, a host, a line break)
    function localPath(uri) {
        const u = String(uri)
        if (!u.startsWith("file:///"))
            return ""
        let p = ""
        try {
            p = decodeURIComponent(u.slice(7))
        } catch (e) {
            return ""
        }
        return p.startsWith("/") && !p.includes("\n") && !p.includes("\0") ? p : ""
    }
    // Dropped files (a drag from the file manager): up to 10 at a time, only
    // local file:// ones, each through the same import, one after another.
    // Says how many came in when some did not
    readonly property int maxDrop: 10
    function importUris(uris) {
        if (busy || !Array.isArray(uris))
            return
        const paths = uris.slice(0, maxDrop).map(localPath).filter(p => p !== "")
        const skipped = Math.min(uris.length, maxDrop) - paths.length + Math.max(0, uris.length - maxDrop)
        let good = 0
        const next = i => {
            if (i >= paths.length) {
                const left = paths.length - good + skipped
                if (left > 0)
                    root.message = left === 1 ? "Uma imagem não entrou (só imagens locais, até 30 MB)"
                                              : `${left} imagens não entraram (só imagens locais, até 30 MB, ${root.maxDrop} por vez)`
                return
            }
            root.importFile(paths[i], ok => {
                if (ok)
                    good++
                next(i + 1)
            })
        }
        if (paths.length === 0) {
            message = "Só imagens locais entram aqui"
            return
        }
        next(0)
    }

    // Escolher arquivo…: the system's file chooser (hypr-escolher-imagem,
    // the portal), only images; cancelled, nothing happens. The settings,
    // a layer over the windows, would cover the chooser: they close while it
    // is open (their usual closing) and come back on this page when it
    // answers, unless something else was opened meanwhile
    property bool picking: false
    function pickFile() {
        if (busy || picking)
            return
        picking = true
        message = ""
        const monitor = ShellState.openOn
        const wasOpen = ShellState.openPanel === "settings" && monitor !== ""
        if (wasOpen)
            ShellState.close()
        const token = "dotfiles" + Math.floor(Math.random() * 1e9)
        run(["hypr-escolher-imagem", token], (code, out) => {
            root.picking = false
            const path = root.localPath(out.trim())
            if (wasOpen && ShellState.openPanel === "" && !LockState.locked && !LockState.wanted) {
                ShellState.settingsPage = ""
                ShellState.settingsPage = "papel"
                ShellState.openPanel = "settings"
                ShellState.openOn = monitor
            }
            if (path !== "")
                root.importFile(path)
        })
    }

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
