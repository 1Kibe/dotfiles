pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Background of the lock and login screens: the picture chosen in
// lock/BackgroundPicker, with its blur and darkening already applied, in a
// folder the login screen can read (/usr/local/share/dotfiles/login, created
// by install.sh). Session only: the login screen just reads fundo.png.
//
// - Lists: the three tabs of the picker. Only files whose real type is PNG,
//   JPEG or WebP, up to 30 MB, regular (no symlink or FIFO) are listed, so Qt
//   never decodes anything else; choosing and applying check again.
// - Apply: ffmpeg renders the final picture (blur and darkening built in,
//   no metadata) into a temp file in the folder; this moves it over
//   fundo.png atomically and saves the controls in fundo.json. The picker's
//   preview is drawn live by Qt with the same look.
Singleton {
    id: root

    readonly property string sharedDir: "/usr/local/share/dotfiles/login"
    // Read by lock/LockScreen (LockBackground) and, later, the login screen
    readonly property string picture: `${sharedDir}/fundo.png`
    readonly property string settingsFile: `${sharedDir}/fundo.json`
    readonly property int maxBytes: 30 * 1024 * 1024

    // ── Controls, remembered in fundo.json ──
    property real blur: Theme.lockBlurDefault      // 0..1 (shown as 0..100%)
    property real darken: Theme.lockDarkenDefault  // 0..1
    property string chosen: ""                     // the original picture last applied

    // ── Picker ──
    property bool pickerOpen: false
    property string focusName: ""     // monitor the picker opens on
    property string tab: "repo"       // "repo" | "pictures" | "captures"
    property var files: []            // checked pictures of the current tab
    property bool busy: false         // applying
    property string message: ""       // last error, in Portuguese; "" = none

    readonly property string home: Quickshell.env("HOME")
    property string picturesDir: `${home}/Pictures`
    readonly property var tabs: [
        { id: "repo", label: "Do repo", dir: `${home}/.config/wallpapers` },
        { id: "pictures", label: "Imagens", dir: picturesDir },
        { id: "captures", label: "Capturas", dir: `${picturesDir}/Capturas` }
    ]

    // qs ipc call lock background (shell.qml); ignored while locked
    function openPicker(monitor) {
        if (LockState.wanted)
            return
        focusName = monitor || ""
        message = ""
        busy = false
        readSettings()
        showTab(tab)
        pickerOpen = true
    }

    function closePicker() {
        pickerOpen = false
        busy = false
    }

    function showTab(id) {
        const t = tabs.find(x => x.id === id) ?? tabs[0]
        tab = t.id
        files = []
        run(["sh", "-c", listScript, "sh", t.dir, String(maxBytes)], (code, out) => {
            if (root.tab === t.id)
                root.files = out.split("\n").filter(f => f !== "")
        })
    }

    // Folder → checked pictures, one per line, by name. -H follows the folder
    // itself when it is a link (~/.config/wallpapers is one, by stow); inside
    // it, -type f still skips symlinks and FIFOs. Names with a line break are
    // skipped; at most 300.
    readonly property string listScript:
        '[ -d "$1" ] || exit 0\n'
        + 'find -H "$1" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) '
        + '-size -$(($2 + 1))c -print0 | sort -z | head -z -n 300 | while IFS= read -r -d "" f; do\n'
        + '  case "$f" in *"\n"*) continue ;; esac\n'
        + '  case "$(file -b --mime-type -- "$f")" in image/png|image/jpeg|image/webp) printf "%s\\n" "$f" ;; esac\n'
        + 'done'

    // One file → its path and `file`'s description when it is a regular
    // file (not a symlink, not a FIFO), up to maxBytes, of real type PNG,
    // JPEG or WebP; else nothing
    readonly property string checkScript:
        'f=$1\n'
        + '[ -L "$f" ] && exit 0\n'
        + '[ -f "$f" ] || exit 0\n'
        + 's=$(stat -c %s -- "$f") || exit 0\n'
        + '[ "$s" -le "$2" ] || exit 0\n'
        + 'm=$(file -b --mime-type -- "$f")\n'
        + 'case "$m" in image/png|image/jpeg|image/webp) ;; *) exit 0 ;; esac\n'
        + 'printf "%s\\n%s\\n%s" "$f" "$m" "$(file -b -- "$f")"'

    // done(ok, width, height, mime): ok = the picture may be opened (by Qt
    // or ffmpeg). The size comes from `file` (the last "W x H": JPEG lines
    // carry the density first)
    function check(path, done) {
        if (typeof path !== "string" || !path.startsWith("/")) {
            done(false, 0, 0, "")
            return
        }
        run(["sh", "-c", checkScript, "sh", path, String(maxBytes)], (code, out) => {
            const lines = out.split("\n")
            if (lines[0] !== path || !decoders[lines[1]]) {
                done(false, 0, 0, "")
                return
            }
            const re = /(\d+) ?x ?(\d+)/g
            let m, last = null
            while ((m = re.exec(lines[2] || "")) !== null)
                last = m
            done(true, last ? parseInt(last[1]) : 0, last ? parseInt(last[2]) : 0, lines[1])
        })
    }

    // ffmpeg's decoder for each checked type: the input format and decoder
    // are fixed, so a disguised file is never read as something else
    readonly property var decoders: ({ "image/png": "png", "image/jpeg": "mjpeg", "image/webp": "webp" })

    // Blur radius as ffmpeg's gaussian sigma, a fraction of the width:
    // measured against the preview (Qt's MultiEffect) on a test picture of
    // white squares, matching the edge width within a few percent at 25, 49
    // and 80 %
    function sigmaFraction(blurAmount) {
        return 0.0062 * Math.sqrt(Math.max(0, Math.min(1, blurAmount)))
    }

    // Renders the final picture into tmpFile with ffmpeg: scaled to the final
    // size, blurred, darkened (like a black veil), no metadata. No shell, a
    // fixed input protocol and format ("file:" also keeps a ":" in the name
    // from becoming a protocol), 15 s at most; the temp file goes on any
    // failure. done(ok).
    function renderFinal(path, mime, sourceWidth, sourceHeight, done) {
        const decoder = decoders[mime]
        if (!decoder || sourceWidth <= 0 || sourceHeight <= 0) {
            done(false)
            return
        }
        const width = finalWidth(sourceWidth, blur)
        const height = Math.max(1, Math.round(width * sourceHeight / sourceWidth))
        const keep = (1 - Math.max(0, Math.min(1, darken))).toFixed(3)
        const filters = [`scale=${width}:${height}:flags=lanczos`, "format=gbrp"]
        if (blur > 0)
            filters.push(`gblur=sigma=${(sigmaFraction(blur) * width).toFixed(2)}`)
        filters.push(`colorchannelmixer=rr=${keep}:gg=${keep}:bb=${keep}`, "format=rgb24")
        run(["timeout", "15", "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
             "-protocol_whitelist", "file", "-c:v", decoder, "-f", "image2", "-i", `file:${path}`,
             "-vf", filters.join(","), "-map_metadata", "-1", "-frames:v", "1",
             "-f", "image2", "-c:v", "png", `file:${tmpFile}`], (code, out) => {
            if (code !== 0) {
                Quickshell.execDetached(["rm", "-f", "--", tmpFile])
                done(false)
                return
            }
            done(true)
        })
    }

    // ── Apply ──
    // renderFinal wrote the final PNG into tmpFile (inside sharedDir): check
    // it again, then move it over fundo.png in one step and save the
    // controls. done(ok).
    readonly property string tmpFile: `${sharedDir}/.fundo-novo.png`

    function finishApply(original, done) {
        run(["sh", "-c", 'f=$1; d=$2; [ -f "$f" ] && [ ! -L "$f" ] && '
             + '[ "$(file -b --mime-type -- "$f")" = image/png ] && mv -T -- "$f" "$d" && echo ok',
             "sh", tmpFile, picture], (code, out) => {
            if (out.trim() !== "ok") {
                Quickshell.execDetached(["rm", "-f", "--", root.tmpFile])
                done(false)
                return
            }
            root.chosen = original
            root.writeSettings()
            done(true)
        })
    }

    // ── fundo.json: only for the picker to remember its controls ──
    FileView {
        id: settings
        path: root.settingsFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    // Up to 4 KB; wrong types or ranges fall back to the defaults
    function parseSettings(text) {
        const out = { blur: Theme.lockBlurDefault, darken: Theme.lockDarkenDefault, chosen: "" }
        if (typeof text !== "string" || text.length === 0 || text.length > 4096)
            return out
        let j
        try {
            j = JSON.parse(text)
        } catch (e) {
            return out
        }
        if (j === null || typeof j !== "object" || Array.isArray(j))
            return out
        if (typeof j.blur === "number" && isFinite(j.blur) && j.blur >= 0 && j.blur <= 1)
            out.blur = j.blur
        if (typeof j.darken === "number" && isFinite(j.darken) && j.darken >= 0 && j.darken <= 1)
            out.darken = j.darken
        if (typeof j.chosen === "string" && j.chosen.startsWith("/") && j.chosen.length < 1024)
            out.chosen = j.chosen
        return out
    }

    function readSettings() {
        settings.reload()
        const s = parseSettings(settings.text())
        blur = s.blur
        darken = s.darken
        chosen = s.chosen
    }

    function writeSettings() {
        settings.setText(JSON.stringify({
            blur: Math.round(blur * 100) / 100,
            darken: Math.round(darken * 100) / 100,
            chosen: chosen
        }) + "\n")
    }

    // ── The size of the final picture ──
    // The blur is a fraction of the picture's width, so the preview and the
    // PNG look alike at any size. A blurred picture loses nothing by being
    // smaller: it is saved at the width where the preview's blur would be
    // about 24 px. No blur: up to 3840 px, never larger than the source.
    function finalWidth(sourceWidth, blurAmount) {
        const full = Math.min(3840, Math.max(1, sourceWidth))
        if (blurAmount <= 0)
            return full
        return Math.max(320, Math.min(full, Math.round(24 / blurFraction(blurAmount))))
    }

    // The preview's blur radius as a fraction of the width: 100% = 2.5%
    function blurFraction(blurAmount) {
        return Math.max(0, Math.min(1, blurAmount)) * 0.025
    }

    // ── Helpers ──
    component Job: Process {
        property var done: null
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            if (done)
                done(code, out.text)
            destroy()
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

    // Pictures folder of this user (xdg-user-dirs)
    Process {
        running: true
        command: ["xdg-user-dir", "PICTURES"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim()
                if (d.startsWith("/"))
                    root.picturesDir = d
            }
        }
    }
}
