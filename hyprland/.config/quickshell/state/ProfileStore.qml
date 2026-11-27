pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/profile.js" as Profile
import "../settings/schema.js" as Schema
import "../settings/validate.js" as Validate
import "../theme/palettes.js" as Palettes

// The profiles (Configurações → Perfis, Super+T): the built-in Padrão (the
// repo's defaults, the repo's wallpaper, never removed, renamed or written)
// and the owner's own, each a folder in ~/.local/share/dotfiles/profiles
// named by its id (drawn by the shell), with perfil.json and maybe
// papel.png and miniatura.png. Everything on disk goes through scripts with
// their arguments in a list: every folder from HOME down a real folder of the
// user's (never a link, cd -P each), files of the user's, regular, never
// links, within their sizes, written through a temporary file in the folder
// and renamed over (mv -T), folders 700, files 600. A picture that comes in is
// always re-encoded by ffmpeg out of the shell (dimensions from its header,
// at most 40 megapixels, under a time and a memory limit, no metadata) to
// papel.png, its longest side at most the largest screen's (3840 at most),
// reduced (with a notice) when it would pass 30 MB, and miniatura.png made
// from it (640 px). Nothing runs with the screen locked. `failed(message)`
// says what did not work, in fixed words.
Singleton {
    id: root

    signal failed(string message)
    signal done(string what, string id)

    // ── Where: the chain from HOME ──
    readonly property string home: Quickshell.env("HOME")
    readonly property string dataDir: Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"
    readonly property var chain: {
        const under = dataDir.startsWith(home + "/")
        const rel = (under ? dataDir.slice(home.length + 1) : "").split("/").filter(c => c !== "")
        const comps = rel.concat(["dotfiles", "profiles"])
        const ok = home !== "" && comps.every(c => c !== "." && c !== ".." && !c.includes("\0"))
        return ok ? { start: under ? home : dataDir, comps: comps } : null
    }
    readonly property string baseDir: `${dataDir}/dotfiles/profiles`
    // The picture's path as the setting keeps it ("~/..." under HOME)
    function papelPath(id) {
        const p = `${baseDir}/${id}/${Profile.PAPEL}`
        return p.startsWith(home + "/") ? "~" + p.slice(home.length) : p
    }
    function miniPath(id) {
        return `${baseDir}/${id}/miniatura.png`
    }

    // ── The profiles ──
    readonly property var keys: Profile.profileKeys(Schema)
    // The profile keys of a value map (the QML engine has no Object.fromEntries)
    function pick(map) {
        const out = {}
        for (const k of keys)
            out[k] = map[k]
        return out
    }
    // The built-in Padrão: the repo's defaults of the profile keys
    readonly property var padrao: ({
        id: "", nome: "Padrão", builtin: true, papel: false, mini: false,
        valores: SettingsStore.ready ? pick(SettingsStore.defaults) : ({})
    })
    // The owner's own, read from the folder: { id: { id, nome, valores, papel, mini } }
    property var found: ({})
    property bool ready: false
    // In the order kept (profileOrder), the folders not in it at the end by
    // their id; the Padrão always first
    readonly property var order: {
        const kept = (SettingsStore.values.profileOrder || []).filter(id => Object.prototype.hasOwnProperty.call(found, id))
        const rest = Object.keys(found).filter(id => !kept.includes(id)).sort()
        return kept.concat(rest)
    }
    // The cards' list: reassigned only when what they show changes (the
    // order is rebuilt on every change of the settings; a new list would
    // make every card again, its picture too)
    property var profiles: []
    property string profilesKey: ""
    function relist() {
        const list = [padrao].concat(order.map(id => found[id]))
        const key = JSON.stringify(list) + "|" + stamp
        if (key !== profilesKey) {
            profilesKey = key
            profiles = list
        }
    }
    onOrderChanged: relist()
    onPadraoChanged: relist()
    onStampChanged: relist()
    readonly property string active: Object.prototype.hasOwnProperty.call(found, SettingsStore.values.profileActive ?? "")
                                     ? SettingsStore.values.profileActive : ""
    // What a card shows (the page's and the carousel's): the picture, as a
    // file URL ("" = none: the large seal), the Padrão with the repo's; the
    // reading's stamp makes a rewritten file load again
    property int stamp: 0
    // The repo's wallpaper is there (the Padrão's card shows it)
    property bool repoPicture: false
    function pictureUrl(p) {
        let path = ""
        if (p === null)
            return ""
        if (p.builtin)
            path = repoPicture ? Validate.expandPath(SettingsStore.defaults.wallpaper ?? "", home) : ""
        else if (p.mini)
            path = miniPath(p.id)
        else if (p.papel)
            path = Validate.expandPath(papelPath(p.id), home)
        return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/") + "?v=" + stamp
    }
    // Its colors: its theme resolved for its flavor and accent (the repo's
    // theme when the catalog has not its own)
    function colorsOf(p) {
        if (p === null)
            return null
        const t = ThemeCatalog.get(p.valores.theme) ?? ThemeCatalog.get(SettingsStore.defaults.theme ?? "")
        return Palettes.resolve(t, p.valores.flavor, p.valores.accent)
    }
    function get(id) {
        return id === "" ? padrao : (Object.prototype.hasOwnProperty.call(found, id) ? found[id] : null)
    }
    // What applying a profile sets: its values and its wallpaper (the
    // profile's picture, or the repo's)
    function wanted(p) {
        const m = Object.assign({}, p.valores)
        m.wallpaper = p.papel ? papelPath(p.id) : SettingsStore.defaults.wallpaper
        return m
    }
    // Today's values differ from the active profile's ("alterado")
    readonly property bool dirty: {
        const p = get(active)
        if (p === null || !SettingsStore.ready)
            return false
        const w = wanted(p)
        return !Profile.sameValues(w, SettingsStore.values, keys) || !samePath(w.wallpaper, SettingsStore.values.wallpaper)
    }
    readonly property bool locked: LockState.locked || LockState.wanted
    // (a write counts from the call: Process.running turns true later)
    property bool writing: false
    readonly property bool busy: writing || worker.running || reader.running
    // For the page: reading (the list) or writing (one of the actions)
    readonly property bool reading: reader.running && !writing && !worker.running

    // ── The scripts ──
    // The chain's walk: $1 start, $2 make missing folders (1 or 0), $3 $4 $5
    // for the script after it, then the folders; ends inside the last one
    // (exit 3: a folder missing, nothing there)
    readonly property string chainScript:
        'umask 077\n'
        + 'start=$1; mk=$2; a=$3; b=$4; c=$5; shift 5\n'
        + 'cd -P -- "$start" 2>/dev/null || exit 1\n'
        + '[ -O . ] || exit 1\n'
        + 'for x; do\n'
        + '  if [ -e "$x" ] || [ -L "$x" ]; then [ -d "$x" ] && [ ! -L "$x" ] && [ -O "$x" ] || exit 1\n'
        + '  elif [ "$mk" = 1 ]; then mkdir -m 700 -- "$x" || exit 1\n'
        + '  else exit 3; fi\n'
        + '  cd -P -- "$x" || exit 1\n'
        + 'done\n'
        + 'chmod 700 . || exit 1\n'
        // the decoders' limits: memory, CPU time, the size of what they
        // write, no core file
        + 'lim="--as=2000000000 --cpu=60 --fsize=64000000 --core=0"\n'
        // a file of the user's, regular, not a link, at most $2 bytes
        + 'okfile() { [ -f "$1" ] && [ ! -L "$1" ] && [ -O "$1" ] && [ "$(stat -c %s -- "$1")" -le "$2" ]; }\n'
        // a file's real type (libmagic under a time limit)
        + 'mime() { timeout -k 2 5 file -b --mime-type -- "$1" 2>/dev/null; }\n'
        // a picture of the profile's: a file as above, and a real PNG
        + 'okpng() { okfile "$1" "$2" && [ "$(mime "$1")" = image/png ]; }\n'
        // a profile's folder: its id by the pattern, a real folder of the user's
        + 'okdir() { case "$1" in ""|*[!a-z0-9-]*|-*) return 1 ;; esac; [ "${#1}" -le 32 ] && [ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ]; }\n'
        // A picture re-encoded: $1 source, $2 the folder, $3 the longest side.
        // papel.png and miniatura.png in place, or nothing; prints "reduzido"
        // when it had to shrink to fit 30 MB
        + 'recode() {\n'
        + '  src=$1; d=$2; side=$3; reduced=\n'
        + '  [ -f "$src" ] && [ ! -L "$src" ] || return 1\n'
        + '  [ "$(stat -c %s -- "$src")" -le 268435456 ] || return 1\n'
        // the real type fixes the decoder and the input format: a disguised
        // file is never read as anything else (a playlist, another file)
        + '  case "$(mime "$src")" in image/png) dec=png ;; image/jpeg) dec=mjpeg ;; image/webp) dec=webp ;; *) return 1 ;; esac\n'
        + '  dims=$(timeout -k 2 10 prlimit $lim -- ffprobe -v error -protocol_whitelist file -c:v "$dec" -f image2 -pattern_type none -select_streams v:0 \\\n'
        + '    -show_entries stream=width,height -of csv=p=0 "file:$src" </dev/null 2>/dev/null) || return 1\n'
        + '  w=${dims%%,*}; h=${dims#*,}; h=${h%%,*}\n'
        + '  case "$w$h" in ""|*[!0-9]*) return 1 ;; esac\n'
        + '  [ "$w" -gt 0 ] && [ "$h" -gt 0 ] && [ $((w * h)) -le 40000000 ] || return 1\n'
        + '  t=$(mktemp -- "$d/.papel.XXXXXX") || return 1\n'
        + '  for try in 1 2 3; do\n'
        + '    timeout -k 2 60 prlimit $lim -- ffmpeg -nostdin -hide_banner -loglevel error -threads 1 -y \\\n'
        + '      -protocol_whitelist file -max_pixels 40000000 -err_detect explode -xerror -c:v "$dec" -f image2 -pattern_type none -i "file:$src" -frames:v 1 -map_metadata -1 \\\n'
        + '      -vf "scale=\'if(gte(iw,ih),min($side,iw),-2)\':\'if(gte(iw,ih),-2,min($side,ih))\'" -f image2 -update 1 -c:v png "file:$t" </dev/null \\\n'
        + '      || { rm -f -- "$t"; return 1; }\n'
        + '    [ "$(stat -c %s -- "$t")" -le 31457280 ] && break\n'
        + '    [ "$try" = 3 ] && { rm -f -- "$t"; return 1; }\n'
        + '    side=$((side * 7 / 10)); reduced=1\n'
        + '  done\n'
        + '  [ "$(mime "$t")" = image/png ] || { rm -f -- "$t"; return 1; }\n'
        + '  chmod 600 -- "$t" && mv -fT -- "$t" "$d/papel.png" || { rm -f -- "$t"; return 1; }\n'
        + '  [ -n "$reduced" ] && echo reduzido\n'
        + '  mini "$d"\n'
        + '  return 0\n'
        + '}\n'
        // miniatura.png from papel.png (640 px, at most 1 MB), or none; $2
        // the seconds it may take (30; the listing gives 15: three of them
        // and their kills fit its 60)
        + 'mini() {\n'
        + '  m=$(mktemp -- "$1/.mini.XXXXXX") || return 0\n'
        + '  if [ "$(mime "$1/papel.png")" = image/png ] && timeout -k 2 "${2:-30}" prlimit $lim -- ffmpeg -nostdin -hide_banner -loglevel error -threads 1 -y \\\n'
        + '       -protocol_whitelist file -max_pixels 40000000 -err_detect explode -xerror -c:v png -f image2 -pattern_type none -i "file:$1/papel.png" -frames:v 1 -map_metadata -1 \\\n'
        + '       -vf "scale=\'if(gte(iw,ih),min(640,iw),-2)\':\'if(gte(iw,ih),-2,min(640,ih))\'" -f image2 -update 1 -c:v png "file:$m" </dev/null \\\n'
        + '     && [ "$(stat -c %s -- "$m")" -le 1048576 ]; then chmod 600 -- "$m" && mv -fT -- "$m" "$1/miniatura.png"; else rm -f -- "$m" "$1/miniatura.png"; fi\n'
        + '}\n'
        // perfil.json from stdin (written through a temporary file); $2
        // "sem": its picture did not pass, so the file says none
        + 'writejson() {\n'
        + '  j=$(mktemp -- "$1/.perfil.XXXXXX") || return 1\n'
        + '  if [ "${2:-}" = sem ]; then head -c 65536 | sed \'s/^  "papel": "papel.png"$/  "papel": null/\' > "$j"; else head -c 65536 > "$j"; fi\n'
        + '  chmod 600 -- "$j" && mv -fT -- "$j" "$1/perfil.json" || { rm -f -- "$j"; return 1; }\n'
        + '}\n'
        // leftovers of an interrupted write (older than 5 minutes)
        + 'find . -mindepth 2 -maxdepth 2 -type f \\( -name ".papel.*" -o -name ".mini.*" -o -name ".perfil.*" -o -name ".copia.*" \\) -mmin +5 -delete 2>/dev/null\n'
    // The list: the folders by the pattern (the first 300 by name looked
    // at, never one reached through a link), each perfil.json as base64 with
    // the pictures' marks; a missing miniature is made again from the
    // picture, at most 3 a reading (the rest on the next ones)
    readonly property string listScript: chainScript
        // first: whether the repo's wallpaper ($a) is there (the Padrão's card)
        + 'if [ -f "$a" ]; then echo "repo 1"; else echo "repo 0"; fi\n'
        + 'made=0\n'
        + 'find . -mindepth 1 -maxdepth 1 -type d -print0 | LC_ALL=C sort -z | head -z -n 300 | while IFS= read -r -d "" p; do\n'
        + '  id=${p#./}\n'
        + '  okdir "$id" || continue\n'
        + '  okfile "$id/perfil.json" 65536 || continue\n'
        + '  pa=0; okpng "$id/papel.png" 31457280 && pa=1\n'
        + '  mi=0; [ "$pa" = 1 ] && okpng "$id/miniatura.png" 1048576 && mi=1\n'
        + '  if [ "$pa" = 1 ] && [ "$mi" = 0 ] && [ "$made" -lt 3 ]; then\n'
        + '    made=$((made + 1)); [ -L "$id/miniatura.png" ] && rm -f -- "$id/miniatura.png"; mini "$id" 15; okpng "$id/miniatura.png" 1048576 && mi=1\n'
        + '  fi\n'
        + '  printf "%s %s %s " "$id" "$pa" "$mi"; head -c 65536 -- "$id/perfil.json" | base64 -w0; echo\n'
        + 'done\n'
    // New ($a the id, $b the picture to re-encode or "", $c the longest
    // side; stdin the perfil.json): the folder made new (never one there)
    readonly property string createScript: chainScript
        + 'case "$a" in ""|*[!a-z0-9-]*|-*) exit 1 ;; esac\n'
        + 'mkdir -m 700 -- "$a" || exit 1\n'
        + 'cd -P -- "$a" && cd .. || exit 1\n'
        + 'sem=; if [ -n "$b" ]; then recode "$b" "$a" "$c" || { echo sempapel; sem=sem; }; fi\n'
        + 'writejson "$a" "$sem" || { rm -rf --one-file-system -- "$a"; exit 1; }\n'
        + 'echo ok\n'
    // Rewrite ($a the id, $b a new picture or "", $c the side; stdin the
    // perfil.json); $b "-": drop the picture
    readonly property string writeScript: chainScript
        + 'okdir "$a" || exit 1\n'
        + 'if [ "$b" = "-" ]; then rm -f -- "$a/papel.png" "$a/miniatura.png"\n'
        + 'elif [ -n "$b" ]; then recode "$b" "$a" "$c" || { echo sempapel; [ -f "$a/papel.png" ] || sem=sem; }; fi\n'
        + 'writejson "$a" "${sem:-}" || exit 1\n'
        + 'echo ok\n'
    // Duplicate ($a from, $b the new id; stdin the new perfil.json): only
    // the known files, by their fixed names, read without following a link
    // (the miniature made again when it does not pass)
    readonly property string duplicateScript: chainScript
        + 'okdir "$a" || exit 1\n'
        + 'case "$b" in ""|*[!a-z0-9-]*|-*) exit 1 ;; esac\n'
        + 'mkdir -m 700 -- "$b" || exit 1\n'
        + 'cpfix() { t=$(mktemp -- "$b/.copia.XXXXXX") && dd if="$a/$1.png" of="$t" iflag=nofollow bs=65536 status=none && chmod 600 -- "$t" && mv -fT -- "$t" "$b/$1.png"; }\n'
        + 'if okpng "$a/papel.png" 31457280; then\n'
        + '  cpfix papel || { rm -rf --one-file-system -- "$b"; exit 1; }\n'
        + '  if okpng "$a/miniatura.png" 1048576; then cpfix miniatura || mini "$b"; else mini "$b"; fi\n'
        + 'fi\n'
        + 'writejson "$b" || { rm -rf --one-file-system -- "$b"; exit 1; }\n'
        + 'echo ok\n'
    // Remove ($a the id): a real folder of the user's whose real path is
    // this one's, then removed without leaving this file system
    readonly property string removeScript: chainScript
        + 'okdir "$a" || exit 1\n'
        + '[ "$(readlink -f -- "$a")" = "$(pwd -P)/$a" ] || exit 1\n'
        + 'rm -rf --one-file-system -- "$a" || exit 1\n'
        + 'echo ok\n'

    // The longest side a picture keeps: the largest screen's, 3840 at most
    readonly property int maxSide: {
        let m = 1920
        for (const s of Quickshell.screens)
            m = Math.max(m, s.width, s.height)
        return Math.min(3840, m)
    }

    // ── Reading ──
    // (a reading asked while one runs runs again after it; profiles wait
    // for the owner's themes, so one with a theme of theirs keeps it)
    property bool readAgain: false
    function reload() {
        if (!SettingsStore.ready || !ThemeCatalog.ready || !ThemeCatalog.ownRead)
            return
        if (reader.running) {
            readAgain = true
            return
        }
        if (chain === null) {
            found = {}
            ready = true
            return
        }
        reader.command = ["timeout", "60", "sh", "-c", listScript, "sh", chain.start, "0",
                          Validate.expandPath(SettingsStore.defaults.wallpaper ?? "", home), "", ""].concat(chain.comps)
        reader.running = true
    }
    function decode64(line) {
        const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        if (!/^[A-Za-z0-9+/]*={0,2}$/.test(line) || line.length % 4 !== 0)
            return null
        let pct = ""
        for (let i = 0; i < line.length; i += 4) {
            const n = [0, 1, 2, 3].map(k => line[i + k] === "=" ? 0 : alphabet.indexOf(line[i + k]))
            const bits = (n[0] << 18) | (n[1] << 12) | (n[2] << 6) | n[3]
            const bytes = [(bits >> 16) & 255, (bits >> 8) & 255, bits & 255]
            const count = line[i + 2] === "=" ? 1 : line[i + 3] === "=" ? 2 : 3
            for (let k = 0; k < count; k++)
                pct += "%" + bytes[k].toString(16).padStart(2, "0")
        }
        try {
            return decodeURIComponent(pct)
        } catch (e) {
            return null
        }
    }
    function themeOk(theme, flavor) {
        const t = ThemeCatalog.get(theme)
        return t !== null && Object.prototype.hasOwnProperty.call(t.sabores, flavor)
    }
    // A reading that failed (the chain, the time): what was read stays, the
    // order is not touched
    function readFailed() {
        ready = true
        failed("Não deu para ler os perfis.")
    }
    function parse(out) {
        const got = {}
        let n = 0
        for (const line of out.split("\n")) {
            const parts = line.split(" ")
            if (parts.length === 2 && parts[0] === "repo") {
                repoPicture = parts[1] === "1"
                continue
            }
            if (parts.length !== 4 || !Profile.ID.test(parts[0]) || n >= Profile.MAX)
                continue
            const text = decode64(parts[3])
            if (text === null)
                continue
            const r = Profile.validateProfile(text, Schema, (s, v) => Validate.validate(s, v, home), SettingsStore.defaults, themeOk)
            if (!r.ok)
                continue
            got[parts[0]] = { id: parts[0], nome: r.profile.nome, valores: r.profile.valores,
                              papel: r.profile.papel !== null && parts[1] === "1", mini: parts[2] === "1", builtin: false }
            n++
        }
        found = got
        stamp++
        ready = true
        if (adoptId !== "")
            tryAdopt()
        // The order keeps the folders it knows; new ones at the end
        if (SettingsStore.ready && JSON.stringify(order) !== JSON.stringify(SettingsStore.values.profileOrder || []))
            SettingsStore.setAuto("profileOrder", order)
    }
    Process {
        id: reader
        stdout: StdioCollector {
            id: readerOut
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0 || code === 3)
                root.parse(readerOut.text)
            else
                root.readFailed()
            if (root.readAgain) {
                root.readAgain = false
                root.reload()
            }
        }
    }
    Connections {
        target: SettingsStore
        function onReadyChanged() {
            root.reload()
        }
    }
    Connections {
        target: ThemeCatalog
        function onReadyChanged() {
            root.reload()
        }
        function onOwnReadChanged() {
            root.reload()
        }
    }
    // (born after SettingsStore is ready, padrao never changes: the list is
    // made here too, never empty until the first reading)
    Component.onCompleted: {
        relist()
        Qt.callLater(reload)
    }

    // ── Writing ──
    property string pendingWhat: ""
    property string pendingId: ""
    property string pendingInput: ""
    function runWorker(what, id, script, args, input) {
        pendingWhat = what
        pendingId = id
        pendingInput = input
        worker.command = ["timeout", "180", "sh", "-c", script, "sh", chain.start, what === "create" || what === "duplicate" ? "1" : "0"]
                         .concat(args).concat(chain.comps)
        worker.stdinEnabled = input !== ""
        writing = true
        worker.running = true
    }
    Process {
        id: worker
        stdout: StdioCollector {
            id: workerOut
        }
        stderr: StdioCollector {}
        onRunningChanged: {
            if (running && root.pendingInput !== "") {
                write(root.pendingInput)
                stdinEnabled = false
            }
        }
        onExited: code => {
            const out = workerOut.text
            const ok = code === 0 && out.split("\n").includes("ok")
            const what = root.pendingWhat, id = root.pendingId
            root.pendingInput = ""
            root.writing = false
            if (!ok)
                root.failed("Não deu para gravar o perfil: nada mudou.")
            else if (out.includes("sempapel"))
                root.failed("A imagem não serviu (tipo, tamanho ou arquivo): o perfil ficou sem papel próprio.")
            else if (out.includes("reduzido"))
                root.failed("A imagem era grande demais: foi reduzida para caber.")
            if (ok && what === "remove")
                root.removed(id)
            root.reload()
            if (ok)
                root.done(what, id)
        }
    }
    // A picture to keep: the wallpaper of today, as a local path (none:
    // the repo's own or not set)
    function currentPicture() {
        const v = Validate.expandPath(SettingsStore.values.wallpaper ?? "", home)
        return typeof v === "string" && v.startsWith("/") && v !== Validate.expandPath(SettingsStore.defaults.wallpaper, home) ? v : ""
    }
    function canWrite() {
        return SettingsStore.ready && ready && chain !== null && !busy && !locked
    }

    // "Salvar como perfil": today's values and wallpaper as a new profile
    function save(nome) {
        if (!canWrite() || !Profile.checkName(nome) || Object.keys(found).length >= Profile.MAX)
            return false
        const id = Profile.newId(Math.random, Object.keys(found))
        if (id === "")
            return false
        const pic = currentPicture()
        const valores = pick(SettingsStore.values)
        runWorker("create", id, createScript, [id, pic, String(maxSide)],
                  Profile.serialize({ nome: nome, valores: valores, papel: pic !== "" ? Profile.PAPEL : null }))
        return true
    }
    // "Salvar no perfil": today's values into the active one (never the
    // Padrão); a wallpaper changed since is re-encoded into it
    function saveActive() {
        const p = get(active)
        if (!canWrite() || p === null || p.builtin)
            return false
        const valores = pick(SettingsStore.values)
        const kept = samePath(SettingsStore.values.wallpaper, papelPath(p.id))
        const pic = kept ? "" : currentPicture()
        const papel = kept ? p.papel : pic !== ""
        runWorker("write", p.id, writeScript, [p.id, kept ? "" : (pic !== "" ? pic : "-"), String(maxSide)],
                  Profile.serialize({ nome: p.nome, valores: valores, papel: papel ? Profile.PAPEL : null }))
        return true
    }
    function rename(id, nome) {
        const p = get(id)
        if (!canWrite() || p === null || p.builtin || !Profile.checkName(nome))
            return false
        runWorker("rename", id, writeScript, [id, "", String(maxSide)],
                  Profile.serialize({ nome: nome, valores: p.valores, papel: p.papel ? Profile.PAPEL : null }))
        return true
    }
    function duplicate(id) {
        const p = get(id)
        if (!canWrite() || p === null || p.builtin || Object.keys(found).length >= Profile.MAX)
            return false
        const nid = Profile.newId(Math.random, Object.keys(found))
        const base = p.nome.length > 25 ? p.nome.slice(0, 25).trim() : p.nome
        const nome = Profile.checkName(base + " cópia") ? base + " cópia" : base
        runWorker("duplicate", nid, duplicateScript, [id, nid, ""],
                  Profile.serialize({ nome: nome, valores: p.valores, papel: p.papel ? Profile.PAPEL : null }))
        return true
    }
    // Removing one: once its folder is gone, today's wallpaper goes back to
    // the repo's when it was this profile's picture, and the active one
    // becomes the Padrão (removed)
    function remove(id) {
        const p = get(id)
        if (!canWrite() || p === null || p.builtin)
            return false
        runWorker("remove", id, removeScript, [id, "", ""], "")
        return true
    }
    function samePath(a, b) {
        const x = Validate.expandPath(a ?? "", home), y = Validate.expandPath(b ?? "", home)
        return x !== "" && x.replace(/\/+/g, "/") === y.replace(/\/+/g, "/")
    }
    function removed(id) {
        if (samePath(SettingsStore.values.wallpaper, papelPath(id))
                && !SettingsStore.setMany({ wallpaper: SettingsStore.defaults.wallpaper }))
            failed("O papel de parede não voltou ao do repo.")
        if (SettingsStore.values.profileActive === id)
            SettingsStore.setAuto("profileActive", "")
    }
    // A profile just saved from how things are now becomes the active one,
    // without applying it again: only when today's values are its values
    // (its picture is a re-encoded copy of today's wallpaper: the wallpaper
    // then points at that copy, the same picture)
    // (asked right after the write: done once the reading has it)
    property string adoptId: ""
    function adoptActive(id) {
        adoptId = id
        if (get(id) !== null)
            tryAdopt()
        return true
    }
    function tryAdopt() {
        const id = adoptId
        adoptId = ""
        const p = get(id)
        if (p === null || p.builtin || !SettingsStore.ready || locked)
            return false
        if (!Profile.sameValues(wanted(p), SettingsStore.values, keys))
            return false
        if (!samePath(wanted(p).wallpaper, SettingsStore.values.wallpaper)) {
            if (!p.papel || !SettingsStore.setMany({ wallpaper: papelPath(id) }))
                return false
        }
        SettingsStore.setAuto("profileActive", id)
        return true
    }
    // A new place in the order (0: right after the Padrão)
    function move(id, to) {
        if (!SettingsStore.ready || !order.includes(id))
            return false
        const list = order.filter(x => x !== id)
        list.splice(Math.max(0, Math.min(list.length, to)), 0, id)
        return SettingsStore.setAuto("profileOrder", list)
    }
    // Applying one: its values and its wallpaper in one change, then it is
    // the active one, through the change of the frozen frame (SwapState: it
    // may happen a moment later, or after the change going on; checked again
    // then). opts.fromCursor: the circle starts from the cursor
    function apply(id, opts) {
        const p = get(id)
        if (p === null || !SettingsStore.ready || locked)
            return false
        // (a click never stays silent: the folders are being read or written)
        if (busy) {
            failed("Espere: os perfis ainda estão sendo lidos ou gravados.")
            return false
        }
        if (SwapState.run(() => applyNow(id), opts))
            return true
        if (SwapState.refusal !== "")
            failed(SwapState.refusal)
        return false
    }
    function applyNow(id) {
        const p = get(id)
        if (p === null || !SettingsStore.ready || locked)
            return false
        if (busy) {
            failed("Espere: os perfis ainda estão sendo lidos ou gravados.")
            return false
        }
        const m = wanted(p)
        // (only the profile's keys and the wallpaper: setMany refuses any other)
        const batch = {}
        for (const k of keys.concat(["wallpaper"]))
            batch[k] = m[k]
        if (!SettingsStore.setMany(batch)) {
            failed("Não deu para aplicar o perfil: nada mudou.")
            return false
        }
        SettingsStore.setAuto("profileActive", id)
        return true
    }
}
