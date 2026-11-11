pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/photo.js" as Photo

// The user's photo (~/.face), shown by the lock screen (the login screen
// keeps the initial and never reads it). Chosen in Configurações → Bloqueio
// e login → Foto from the same folders as the wallpaper gallery, with the
// same checks (BackgroundStore: regular files only, no link, up to 30 MB, of
// real type PNG, JPEG or WebP), then made into a 512 px square PNG by
// settings/photo.js. `photo` is ~/.face only after it passes that check too
// (it may have been put there by hand).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string faceFile: `${home}/.face`
    // ~/.face when it is a picture that may be shown; "" otherwise
    property string photo: ""
    // Bumped at every change, so an Image showing it reloads
    property int version: 0
    property bool busy: false
    property string message: ""

    // The gallery's tabs: the wallpaper's folders
    readonly property var tabs: WallpaperStore.tabs
    property string tab: "pictures"
    property var files: []

    function showTab(id) {
        const t = tabs.find(x => x.id === id) ?? tabs[0]
        tab = t.id
        files = []
        run(["sh", "-c", BackgroundStore.listScript, "sh", t.dir, String(BackgroundStore.maxBytes)], (code, out) => {
            if (root.tab === t.id)
                root.files = out.split("\n").filter(f => f !== "")
        })
    }

    function refresh() {
        BackgroundStore.check(faceFile, ok => {
            root.photo = ok ? root.faceFile : ""
            root.version++
        })
    }
    Component.onCompleted: refresh()

    // A picture of the gallery (a path it listed) becomes the photo
    function choose(path) {
        if (busy || typeof path !== "string" || !path.startsWith("/") || path.includes("\n"))
            return
        busy = true
        message = ""
        run(["timeout", "30", "sh", "-c", Photo.setScript, "sh", path, faceFile, String(BackgroundStore.maxBytes)], (code, out) => {
            root.busy = false
            if (code !== 0 || out.trim() !== "ok")
                root.message = "Não deu para usar essa imagem"
            root.refresh()
        })
    }

    // "Tirar foto": back to the initial
    function remove() {
        if (busy)
            return
        busy = true
        message = ""
        run(["sh", "-c", Photo.removeScript, "sh", faceFile], (code, out) => {
            root.busy = false
            if (code !== 0)
                root.message = "Não deu para tirar a foto"
            root.refresh()
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
