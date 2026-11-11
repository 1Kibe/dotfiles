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
import "settings/schema.js" as Schema

// The shell: one bar per monitor. Later modules (launcher, notifications...)
// get their own folder and a line here.
ShellRoot {
    // The settings (Configurações): singletons load when first used, so the
    // shell touches both at start; the store reads the choices, the other
    // takes them out of the shell
    readonly property bool settingsReady: SettingsStore.ready && SettingsApply.handlers !== null

    // Desktop wallpaper, below every window
    Wallpaper {}

    // Each Bar (the frame: bar and its panels) gets its screen as modelData;
    // bars are added and removed as monitors are plugged in and out. BarZone
    // reserves the bar's space, since the frame grows over the windows.
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {}
        }
    }
    Variants {
        model: Quickshell.screens
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

    // Super+X and Ctrl+Alt+Del: power menu on the focused monitor's bar
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
    // qs ipc call panel toggle network   (power, network, volume, bluetooth, media, system)
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
            if (!ShellState.isOpen("settings", monitor.name))
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
