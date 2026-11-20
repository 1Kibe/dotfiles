import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.capture
import qs.clipboard
import qs.lock
import qs.wallpaper
import qs.state
import qs.settings
import qs.overview
import "settings/schema.js" as Schema
import "bar/barscreens.js" as BarScreens

// The shell: one bar per monitor. Later modules (launcher, notifications...)
// get their own folder and a line here.
ShellRoot {
    // The settings (Configurações): singletons load when first used, so the
    // shell touches both at start; the store reads the choices, the other
    // takes them out of the shell
    readonly property bool settingsReady: SettingsStore.ready && SettingsApply.handlers !== null
    // The night light keeps its hours with the panel closed too
    readonly property bool nightLightOn: NightLight.wanted

    // Desktop wallpaper, below every window
    Wallpaper {}

    // Each Bar (the frame: bar and its panels) gets its screen as modelData;
    // bars are added and removed as monitors are plugged in and out. BarZone
    // reserves the bar's space, since the frame grows over the windows. Only
    // on the screen chosen in "Mostrar a barra em" when it is there; on
    // every screen otherwise (bar/barscreens.js)
    readonly property string barMonitor: SettingsStore.ready ? String(SettingsStore.get("barMonitor")) : ""
    readonly property var barScreens: {
        const names = BarScreens.pick(Quickshell.screens.map(s => s.name), barMonitor)
        return Quickshell.screens.filter(s => names.includes(s.name))
    }
    // Keybinds from a screen with no bar open its panels on the bar's screen
    Binding {
        target: ShellState
        property: "barScreens"
        value: barScreens.map(s => s.name)
    }
    Variants {
        model: barScreens
        delegate: Component {
            Bar {}
        }
    }
    Variants {
        model: barScreens
        delegate: Component {
            BarZone {}
        }
    }
    // The settings' space on the left, only while they show
    Variants {
        model: Quickshell.screens
        delegate: Component {
            SettingsZone {}
        }
    }

    // Print: capture bar and frozen screen, countdown and notices
    CaptureOverlay {}
    Countdown {}
    CaptureToast {}
    CaptureCard {}

    // Configurações → Monitores: "Manter estas telas?" while an arrangement
    // is tried, and the screens' numbers on Identificar
    MonitorKeep {}
    MonitorIdentify {}
    // Configurações → Teclado e mouse: "Manter este teclado?" while a layout
    // is tried
    KeyboardKeep {}

    IpcHandler {
        target: "capture"

        // Print: the capture bar over a frozen screen
        function open(): void {
            CaptureState.openCapture()
        }

        // Super+Shift+T: the text of an area goes to the clipboard
        function ocr(): void {
            CaptureState.openOcr()
        }

        // Super+Alt+R: record the focused monitor, or stop the recording
        function record(): void {
            CaptureState.toggleRecord()
        }

        // A quick print (hypr-print) was saved: its card in the corner.
        // Only a PNG inside the Capturas folder is accepted.
        function card(path: string): void {
            CaptureState.showCard(path)
        }

        // Where and how a quick print saves (hypr-print): JSON with the
        // folder, the file's name and whether it copies
        function target(): string {
            return CaptureState.target()
        }

        // State and counts only, never paths or content: qs ipc call capture stats
        function stats(): string {
            return JSON.stringify(CaptureState.stats())
        }
    }

    // Lock screen (Super+L through hypr-travar, hypridle)
    LockScreen {}

    // The veil and warning before the idle lock (hypridle: lock dim/undim)
    DimOverlay {}

    // Unlocking is never reachable from outside, only through a PAM success
    // on the lock screen
    IpcHandler {
        target: "lock"

        // Asks to lock; does nothing when already locked. hypr-travar then
        // waits for stats().locked
        function lock(): void {
            LockState.lock()
        }

        // {"locked","checking","dimmed","error"}: locked is the compositor's
        // confirmation that every screen is covered; never the password or
        // the user
        function stats(): string {
            return JSON.stringify(LockState.stats())
        }

        // The picker of the lock and login background, on the focused
        // monitor; ignored while locked
        function background(): void {
            const monitor = Hyprland.focusedMonitor
            BackgroundStore.openPicker(monitor ? monitor.name : "")
        }

        // hypridle, before the idle lock: darken with a countdown of the
        // given seconds (hypridle.conf), and back on any key or move. Only a
        // veil: never locks or unlocks
        function dim(seconds: int): void {
            LockState.dim(seconds)
        }

        function undim(): void {
            LockState.undim()
        }
    }

    // Background picker (qs ipc call lock background)
    BackgroundPicker {}

    // Super+V: clipboard history over the focused monitor
    ClipboardOverlay {}

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            // focusedMonitor can be null for a moment (monitors changing):
            // then the key does nothing. Same in the handlers below.
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                ClipboardStore.toggle(monitor.name)
        }

        // Counts only, never content (for tests): qs ipc call clipboard stats
        function stats(): string {
            return JSON.stringify(ClipboardStore.stats())
        }
    }

    // Super+I, F9 and Super+A: the control center on the focused monitor
    // (on the bar's screen when that one has no bar):
    // qs ipc call controlcenter toggle | open <section> | stats
    // open takes only a section of ShellState.controlSections, or "" for all
    // folded; any other text is refused
    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                ShellState.toggleByKey("control", monitor.name)
        }

        function open(section: string): string {
            if (section !== "" && !ShellState.controlSections.includes(section))
                return "seção desconhecida"
            const monitor = Hyprland.focusedMonitor
            if (!monitor)
                return "sem monitor em foco"
            return ShellState.openControl(ShellState.panelScreen(monitor.name), section, true) ? "ok" : "não abriu"
        }

        // States only, never a name (of a network, a device, a package...)
        function stats(): string {
            return JSON.stringify({
                open: ShellState.openPanel === "control",
                section: ShellState.openPanel === "control" ? ShellState.controlSection : "",
                allowed: ShellState.controlAllowed()
            })
        }
    }

    // The updates checked now, as "Verificar agora" (3 s apart, one at a
    // time, never locked); hypr-atualizar calls it when it ends, so the
    // list does not show what was just updated: qs ipc call updates check
    IpcHandler {
        target: "updates"

        function check(): string {
            return Updates.checkNow()
        }
    }

    // The overview's windows, one per screen (shown while it is open)
    Overview {}

    // Super+Tab and the 3-finger swipe up: the overview of the windows,
    // on every screen: qs ipc call overview toggle | open | close
    IpcHandler {
        target: "overview"

        function toggle(): string {
            return OverviewState.toggle()
        }
        function open(): string {
            return OverviewState.open ? "ok" : OverviewState.show()
        }
        function close(): string {
            OverviewState.hide()
            return "ok"
        }
    }

    // Super+H and Super+Shift+H: minimize the focused window, bring the
    // last one back (state/MinimizeState): qs ipc call minimize focused |
    // restoreLast. No free argument: the window and the screen are the
    // focused ones
    IpcHandler {
        target: "minimize"
        // Keeps the minimize state alive from the start (its events)
        readonly property var state: MinimizeState

        function focused(): string {
            const t = Hyprland.activeToplevel
            return t && MinimizeState.minimize(String(t.address || "")) ? "ok" : "nada"
        }
        function restoreLast(): string {
            const m = Hyprland.focusedMonitor
            return MinimizeState.restoreLast(m ? m.name : "") ? "ok" : "nada"
        }
    }

    // Super+X and Ctrl+Alt+Del: the control center on its power section
    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                ShellState.toggleByKey("power", monitor.name)
        }
    }

    // Ctrl+Shift+Esc: system panel (CPU, memory, processes) on the focused monitor
    IpcHandler {
        target: "taskmanager"

        function toggle(): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                ShellState.toggleByKey("system", monitor.name)
        }

        // Numbers of the rings and the panel's list, as JSON (for scripts
        // and tests): qs ipc call taskmanager stats
        function stats(): string {
            return JSON.stringify({
                cpu: SystemStats.cpu,
                cores: SystemStats.cores,
                memUsed: SystemStats.memUsed,
                memTotal: SystemStats.memTotal,
                temp: SystemStats.hasTemp ? SystemStats.temp : null,
                processCount: SystemStats.processCount,
                processes: SystemStats.processes
            })
        }
    }

    // Any bar panel on the focused monitor, for keybinds and scripts:
    // qs ipc call panel toggle network   (control, network, volume, bluetooth, media, system;
    // power and controlcenter are the control center; any other name is ignored)
    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                ShellState.toggleByKey(name, monitor.name)
        }
    }

    // The settings (Super+S), on the focused monitor:
    // qs ipc call settings toggle | open <page> | close
    // A page that is not in settings/schema.js is refused
    IpcHandler {
        target: "settings"

        function open(page: string): string {
            const monitor = Hyprland.focusedMonitor
            if (!monitor || (page !== "" && !Schema.PAGE_IDS.includes(page)))
                return "página desconhecida"
            ShellState.settingsPage = ""
            ShellState.settingsPage = page
            if (!ShellState.isOpen("settings", ShellState.panelScreen(monitor.name)))
                ShellState.toggleByKey("settings", monitor.name)
            return "ok"
        }
        function close(): void {
            if (ShellState.openPanel === "settings")
                ShellState.close()
        }
        function toggle(): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor) {
                ShellState.settingsPage = ""
                ShellState.toggleByKey("settings", monitor.name)
            }
        }
    }
}
