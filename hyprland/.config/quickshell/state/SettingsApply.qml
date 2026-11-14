pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import "../settings/appearance.js" as Appearance
import "../settings/serialize.js" as Serialize
import "../settings/schema.js" as Schema
import "../settings/kitty.js" as Kitty
import "../settings/btop.js" as Btop
import "../settings/input.js" as Input
import "../settings/lazygit.js" as Lazygit

// Takes each new choice of SettingsStore where it goes: inside the shell,
// the Theme's motion; out of it, later, the generated Hyprland files
// (~/.config/hypr/dotfiles_settings.lua), hypridle, xdg-mime,
// localectl, sysfs. Each area comes with its own task; this is
// the frame they hang on: a handler per key, and `failed` with a short
// fixed message in pt-BR, after which the page shows the value as it was.
Singleton {
    id: root

    readonly property string hyprFile: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr/dotfiles_settings.lua`

    signal failed(string key, string message)

    // key -> function(value): set by the areas as they are added
    property var handlers: ({})

    Connections {
        target: SettingsStore
        function onChanged(key) {
            const handler = root.handlers[key]
            if (handler)
                handler(SettingsStore.get(key))
        }
    }

    // Inside the shell: the motion of the Theme (which imports nothing, so
    // the login screen can use it alone)
    function applyMotion() {
        if (!SettingsStore.ready)
            return
        Theme.speed = SettingsStore.get("animSpeed")
        Theme.reduceMotion = SettingsStore.get("reduceMotion") === true
    }
    Connections {
        target: SettingsStore
        function onReadyChanged() {
            root.applyMotion()
            root.applyAppearance()
            root.applyClipboard()
        }
        function onValuesChanged() {
            root.applyMotion()
            root.applyAppearance()
            root.applyClipboard()
        }
        // The cursor of the apps already running (dotfiles_settings.lua covers the
        // ones started later)
        function onChanged(key) {
            if (key === "cursorTheme" || key === "cursorSize")
                root.applyCursor()
        }
    }
    // The machine's lists, once read (each list comes before its flag)
    Connections {
        target: SystemLists
        function onFontsReadChanged() { root.applyAppearance() }
        function onMonoReadChanged() { root.applyAppearance() }
        function onCursorsReadChanged() { root.applyAppearance() }
        function onLayoutsReadChanged() { root.applyAppearance() }
    }
    Component.onCompleted: {
        applyMotion()
        applyAppearance()
        // Configurações → Energia lives in its own singleton: load it
        EnergyApply.applyIdle()
        // So do Apps padrão and Iniciar com o sistema (their data files follow
        // the settings even with the page closed)
        void AppsState.scanned
    }

    // ── Aparência (T4) ──

    // The Theme's own palette, for the accent (settings/appearance.js)
    function palette() {
        return { red: String(Theme.red), green: String(Theme.green), yellow: String(Theme.yellow),
                 blue: String(Theme.blue), purple: String(Theme.purple), aqua: String(Theme.aqua),
                 orange: String(Theme.orange) }
    }

    // The store's choices into the Theme (a font this machine does not have
    // keeps the default), then the Hyprland file
    function applyAppearance() {
        if (!SettingsStore.ready)
            return
        const v = SettingsStore.values
        const pair = Appearance.accentPair(v.accent, palette())
        Theme.accent = pair.accent
        Theme.accentLight = pair.light
        // Kitty's, btop's and lazygit's colors, the accent among them
        applyKitty()
        applyBtop()
        applyLazygit()
        Theme.barOpacity = v.barOpacity
        Theme.barHeight = v.barHeight
        moveBar(v.barPosition === "bottom")
        Theme.radius = v.radius
        Theme.textScale = Appearance.textScale(v.textScale)
        Theme.font = SystemLists.usable("fonts", v.fontUi) ? v.fontUi : SettingsStore.defaults.fontUi
        Theme.monoFont = SystemLists.usable("monoFonts", v.fontMono) ? v.fontMono : SettingsStore.defaults.fontMono
        // The panels' font: the choice, else the default, else the interface's
        Theme.fontPanels = SystemLists.usable("fonts", v.fontPanels) ? v.fontPanels
                         : SystemLists.usable("fonts", SettingsStore.defaults.fontPanels) ? SettingsStore.defaults.fontPanels
                         : Theme.font
        // The Hyprland file only once the cursor themes and the keyboard
        // layouts are known: before, it would come out without those lines
        // and be written twice (two reloads) at every start
        if (!SystemLists.cursorsRead || !SystemLists.layoutsRead)
            return
        let text = ""
        try {
            text = Appearance.hyprLua(v, pair, SystemLists.has("cursorThemes", v.cursorTheme), Serialize.luaValue)
                   + areasLua(v)
        } catch (e) {
            failed("accent", "Não deu para aplicar no Hyprland")
            return
        }
        // Teclado e mouse (settings/input.js): a value that does not pass
        // leaves the whole file as it was. The layout only when it is in
        // the system's list (Hyprland takes any name and silently keeps the
        // old keymap); out of it, it is never applied
        try {
            const layout = SystemLists.has("layouts", v.kbLayout) ? v.kbLayout : ""
            text += Input.inputLua(v, Schema.KEYS, Serialize.luaValue, layout)
        } catch (e) {
            failed("repeatRate", "Não deu para aplicar o teclado e o mouse no Hyprland")
            return
        }
        // A change elsewhere (or the store reading back its own write) that
        // leaves the text as it is does not push the write further away
        if (text === hyprWanted)
            return
        hyprWanted = text
        hyprTimer.restart()
    }

    // Áreas de trabalho (modules/areas.lua reads the global): the mode and
    // each screen's place, the pairs checked again (AreasState.parse) and
    // written through the serializer
    function areasLua(v) {
        const pos = AreasState.parse(String(v.monitorPositions))
        const pairs = Object.keys(pos).map(n => `[${Serialize.luaValue(n)}] = ${Serialize.luaValue(pos[n])}`)
        return "-- Áreas de trabalho (Configurações → Monitores): read by modules/areas.lua\n"
               + `dotfiles_areas = { together = ${Serialize.luaValue(v.areasTogether !== false)}, positions = { ${pairs.join(", ")} } }\n`
    }

    // The bar's edge (Configurações → Barra → Posição): at the first read it
    // just takes it; a change slides the bar out through its edge, flips the
    // edge while it is out of sight, and slides it in through the other one
    // (reduce motion: a fade, Bar.qml)
    property bool barEdgeKnown: false
    property bool barWanted: false
    function moveBar(bottom) {
        barWanted = bottom
        if (!barEdgeKnown) {
            barEdgeKnown = true
            Theme.barAtBottom = bottom
            return
        }
        if (bottom !== Theme.barAtBottom && !barMove.running)
            barMove.restart()
    }
    SequentialAnimation {
        id: barMove
        NumberAnimation {
            target: Theme
            property: "barOut"
            to: 1
            duration: Theme.dur(Theme.animNormal)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveAccel
        }
        ScriptAction { script: Theme.barAtBottom = root.barWanted }
        NumberAnimation {
            target: Theme
            property: "barOut"
            to: 0
            duration: Theme.dur(Theme.motionPanelOpen)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDecel
        }
        // A change asked while it moved
        ScriptAction {
            script: {
                if (root.barWanted !== Theme.barAtBottom)
                    Qt.callLater(() => barMove.restart())
            }
        }
    }

    // ~/.config/hypr/dotfiles_settings.lua (read by hyprland.lua before local.lua):
    // written only when its text changes, half a second after the last
    // change (a slider being dragged is one write, one reload), then
    // Hyprland reads its configuration again. With the session locked
    // nothing is written or reloaded: the unlock writes what is waiting.
    // The folder is the repo's (stow); the file is in its .gitignore.
    property string hyprWanted: ""
    property bool hyprLoaded: false
    readonly property bool locked: LockState.locked || LockState.wanted
    onLockedChanged: if (!locked) hyprTimer.restart()
    Timer {
        id: hyprTimer
        interval: 500
        onTriggered: root.writeHypr()
    }
    function writeHypr() {
        if (!hyprLoaded || hyprWanted === "" || locked)
            return
        if (hyprView.text() === hyprWanted)
            return
        // The write follows a link: the file must be missing or a plain file
        // (settings/serialize.js writeCheck), else nothing is written
        if (hyprStat.running) {
            hyprStatAgain = true
            return
        }
        hyprStat.running = true
    }
    property bool hyprStatAgain: false
    Process {
        id: hyprStat
        command: Serialize.writeCheck(root.hyprFile)
        // Ten seconds at most: a check that hangs is stopped and counts as a
        // refusal whatever it answers then (a program may catch the signal
        // and exit 0), so the next change can still be written. Only a normal
        // exit counts (status 0, QProcess's NormalExit: the enum is not
        // reachable from QML)
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                hyprStatLimit.restart()
            } else {
                hyprStatLimit.stop()
            }
        }
        onExited: (code, status) => {
            if (timedOut || status !== 0 || !Serialize.mayWrite(code))
                root.failed("accent", "O arquivo de configurações do Hyprland é um link ou não pôde ser conferido: nada foi gravado")
            else if (hyprView.text() !== root.hyprWanted && !root.locked)
                hyprView.setText(root.hyprWanted)
            if (root.hyprStatAgain) {
                root.hyprStatAgain = false
                root.writeHypr()
            }
        }
    }
    Timer {
        id: hyprStatLimit
        interval: 10000
        onTriggered: {
            hyprStat.timedOut = true
            hyprStat.running = false
        }
    }
    FileView {
        id: hyprView
        path: root.hyprFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            root.hyprLoaded = true
            root.writeHypr()
        }
        onLoadFailed: {
            root.hyprLoaded = true
            root.writeHypr()
        }
        onSaved: Quickshell.execDetached(["hyprctl", "reload"])
        onSaveFailed: root.failed("accent", "Não deu para salvar a configuração do Hyprland")
    }

    // ── Kitty's colors (settings/kitty.js) ──
    // ~/.config/kitty/cores.conf, included at the end of kitty.conf: written
    // only when its text changes, in one step (atomic write). Kitty reads
    // it again by itself: its auto_reload_config also follows the included
    // files, renamed over or created after it started, so no signal is
    // sent.
    readonly property string kittyDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kitty`
    readonly property string kittyFile: `${kittyDir}/cores.conf`
    property string kittyWanted: ""
    property bool kittyLoaded: false
    function applyKitty() {
        kittyWanted = Kitty.colorsConf({
            bgHard: Theme.bgHard, fg: Theme.fg, bg2: Theme.bg2, gray: Theme.gray, red: Theme.red,
            green: Theme.green, yellow: Theme.yellow, blue: Theme.blue, purple: Theme.purple, aqua: Theme.aqua,
            orange: Theme.orange, accentLight: Theme.accentLight
        })
        writeKitty()
    }
    function writeKitty() {
        if (!kittyLoaded || kittyWanted === "" || kittyView.text() === kittyWanted)
            return
        if (kittyCheck.running) {
            kittyAgain = true
            return
        }
        kittyCheck.running = true
    }
    // The FileView would make a missing folder: a theme file is written
    // only when the app's folder is already there, as the user's own folder
    // or as stow's link to this repo's common/.config/<app> (the shell's
    // folder is the repo's hyprland/.config/quickshell). Without the app,
    // or with a link to anywhere else, nothing is written. $4: a subfolder
    // that, when there, must be a real folder (never a link).
    property bool kittyAgain: false
    readonly property string configDirScript:
        'd=$1; q=$2; rel=$3; sub=$4\n'
        + '[ -d "$d" ] || exit 1\n'
        + 'if [ -L "$d" ]; then\n'
        + '  r=$(readlink -f -- "$q/../../..") && t=$(readlink -f -- "$d") || exit 1\n'
        + '  [ "$t" = "$r/$rel" ] || exit 1\n'
        + 'fi\n'
        + 'if [ -n "$sub" ] && { [ -e "$d/$sub" ] || [ -L "$d/$sub" ]; }; then\n'
        + '  [ -d "$d/$sub" ] && [ ! -L "$d/$sub" ] || exit 1\n'
        + 'fi\n'
        + 'echo ok'
    Process {
        id: kittyCheck
        command: ["sh", "-c", root.configDirScript, "sh", root.kittyDir, Quickshell.shellPath("."), "common/.config/kitty", ""]
        stdout: StdioCollector {
            id: kittyCheckOut
        }
        onExited: code => {
            if (code === 0 && kittyCheckOut.text.trim() === "ok" && kittyView.text() !== root.kittyWanted)
                kittyView.setText(root.kittyWanted)
            if (root.kittyAgain) {
                root.kittyAgain = false
                root.writeKitty()
            }
        }
    }
    FileView {
        id: kittyView
        path: root.kittyFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            root.kittyLoaded = true
            root.writeKitty()
        }
        onLoadFailed: {
            root.kittyLoaded = true
            root.writeKitty()
        }
    }

    // ── btop's colors (settings/btop.js) ──
    // ~/.config/btop/themes/dotfiles.theme, the color_theme of btop.conf:
    // written like Kitty's cores.conf (only when its text changes, atomic,
    // after the same folder check; the themes subfolder is made by the
    // FileView inside a checked btop folder). btop reads it when it opens.
    readonly property string btopDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/btop`
    readonly property string btopFile: `${btopDir}/themes/dotfiles.theme`
    property string btopWanted: ""
    property bool btopLoaded: false
    property bool btopAgain: false
    function applyBtop() {
        btopWanted = Btop.themeText({
            bgHard: Theme.bgHard, bg1: Theme.bg1, bg2: Theme.bg2, fg: Theme.fg, fg4: Theme.fg4, gray: Theme.gray,
            red: Theme.red, green: Theme.green, yellow: Theme.yellow, orange: Theme.orange, blue: Theme.blue,
            purple: Theme.purple, aqua: Theme.aqua, accentLight: Theme.accentLight
        })
        writeBtop()
    }
    function writeBtop() {
        if (!btopLoaded || btopWanted === "" || btopView.text() === btopWanted)
            return
        if (btopCheck.running) {
            btopAgain = true
            return
        }
        btopCheck.running = true
    }
    Process {
        id: btopCheck
        command: ["sh", "-c", root.configDirScript, "sh", root.btopDir, Quickshell.shellPath("."), "common/.config/btop", "themes"]
        stdout: StdioCollector {
            id: btopCheckOut
        }
        onExited: code => {
            if (code === 0 && btopCheckOut.text.trim() === "ok" && btopView.text() !== root.btopWanted)
                btopView.setText(root.btopWanted)
            if (root.btopAgain) {
                root.btopAgain = false
                root.writeBtop()
            }
        }
    }
    FileView {
        id: btopView
        path: root.btopFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            root.btopLoaded = true
            root.writeBtop()
        }
        onLoadFailed: {
            root.btopLoaded = true
            root.writeBtop()
        }
    }

    // ── lazygit's and delta's colors (settings/lazygit.js) ──
    // ~/.config/lazygit/tema.yml (read after the repo's config.yml) and
    // delta.gitconfig (lazygit's diff renderer points delta at it), written
    // like Kitty's cores.conf: only when the text changes, atomic, and only
    // into lazygit's own folder after the same check (stow's link to the
    // repo's common/.config/lazygit, or the user's folder). lazygit reads
    // them when it opens.
    readonly property string lazygitDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/lazygit`
    property string lazygitTheme: ""
    property string lazygitDelta: ""
    property bool lazygitThemeLoaded: false
    property bool lazygitDeltaLoaded: false
    property bool lazygitAgain: false
    function applyLazygit() {
        const colors = {
            bgHard: String(Theme.bgHard), bg1: String(Theme.bg1), bg2: String(Theme.bg2), fg: String(Theme.fg),
            gray: String(Theme.gray), red: String(Theme.red), green: String(Theme.green), yellow: String(Theme.yellow),
            blue: String(Theme.blue), aqua: String(Theme.aqua), accentLight: String(Theme.accentLight)
        }
        try {
            lazygitTheme = Lazygit.themeYaml(colors)
            lazygitDelta = Lazygit.deltaConf(colors)
        } catch (e) {
            return
        }
        writeLazygit()
    }
    function writeLazygit() {
        if (!lazygitThemeLoaded || !lazygitDeltaLoaded || lazygitTheme === "" || lazygitDelta === "")
            return
        if (lazygitThemeView.text() === lazygitTheme && lazygitDeltaView.text() === lazygitDelta)
            return
        if (lazygitCheck.running) {
            lazygitAgain = true
            return
        }
        lazygitCheck.running = true
    }
    Process {
        id: lazygitCheck
        command: ["sh", "-c", root.configDirScript, "sh", root.lazygitDir, Quickshell.shellPath("."), "common/.config/lazygit", ""]
        stdout: StdioCollector {
            id: lazygitCheckOut
        }
        onExited: code => {
            if (code === 0 && lazygitCheckOut.text.trim() === "ok") {
                if (lazygitThemeView.text() !== root.lazygitTheme)
                    lazygitThemeView.setText(root.lazygitTheme)
                if (lazygitDeltaView.text() !== root.lazygitDelta)
                    lazygitDeltaView.setText(root.lazygitDelta)
            }
            if (root.lazygitAgain) {
                root.lazygitAgain = false
                root.writeLazygit()
            }
        }
    }
    FileView {
        id: lazygitThemeView
        path: `${root.lazygitDir}/tema.yml`
        printErrors: false
        atomicWrites: true
        onLoaded: {
            root.lazygitThemeLoaded = true
            root.writeLazygit()
        }
        onLoadFailed: {
            root.lazygitThemeLoaded = true
            root.writeLazygit()
        }
    }
    FileView {
        id: lazygitDeltaView
        path: `${root.lazygitDir}/delta.gitconfig`
        printErrors: false
        atomicWrites: true
        onLoaded: {
            root.lazygitDeltaLoaded = true
            root.writeLazygit()
        }
        onLoadFailed: {
            root.lazygitDeltaLoaded = true
            root.writeLazygit()
        }
    }

    // ── The clipboard history's size (Configurações → Captura e clipboard) ──
    // cliphist reads ~/.config/cliphist/config ("max-items N"): a number of
    // the schema only, written when it changes; the folder is made 700 first
    readonly property string cliphistDir: `${Quickshell.env("HOME")}/.config/cliphist`
    property string cliphistWanted: ""
    function applyClipboard() {
        if (!SettingsStore.ready)
            return
        const n = SettingsStore.get("clipHistory")
        if (!Number.isInteger(n) || n < 20 || n > 500)
            return
        const text = `max-items ${n}\n`
        if (text === cliphistWanted)
            return
        cliphistWanted = text
        Quickshell.execDetached(["mkdir", "-p", "-m", "700", "--", cliphistDir])
        cliphistTimer.restart()
    }
    Timer {
        id: cliphistTimer
        interval: 300
        onTriggered: {
            if (cliphistView.text() !== root.cliphistWanted)
                cliphistView.setText(root.cliphistWanted)
        }
    }
    FileView {
        id: cliphistView
        path: `${root.cliphistDir}/config`
        printErrors: false
        atomicWrites: true
        // The folder may not be there yet the first time: once more, later
        onSaveFailed: cliphistRetry.restart()
    }
    Timer {
        id: cliphistRetry
        interval: 1000
        onTriggered: cliphistView.setText(root.cliphistWanted)
    }

    // The cursor now: Hyprland's and the GTK apps'. Only a theme this machine
    // has (SystemLists) and a size of the schema; argument lists only
    function applyCursor() {
        const theme = SettingsStore.get("cursorTheme")
        const size = SettingsStore.get("cursorSize")
        if (!SystemLists.has("cursorThemes", theme) || !Schema.KEYS.cursorSize.options.some(o => o.value === size))
            return
        Quickshell.execDetached(["hyprctl", "setcursor", theme, String(size)])
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme])
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", String(size)])
    }
}
