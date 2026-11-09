import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.capture
import qs.clipboard
import qs.state

// The shell: one bar per monitor. Later modules (launcher, notifications...)
// get their own folder and a line here.
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {}
        }
    }

    // Print: capture bar and frozen screen, countdown and notices
    CaptureOverlay {}
    Countdown {}
    CaptureToast {}
    CaptureCard {}

    IpcHandler {
        target: "capture"

        function open(): void {
            CaptureState.openCapture()
        }

        // Super+Shift+T: the text of an area goes to the clipboard
        function ocr(): void {
            CaptureState.openOcr()
        }

        // A quick print (hypr-print) was saved: its card in the corner.
        // Only a PNG inside the Capturas folder is accepted.
        function card(path: string): void {
            CaptureState.showCard(path)
        }

        // State and counts only, never paths or content: qs ipc call capture stats
        function stats(): string {
            return JSON.stringify(CaptureState.stats())
        }
    }

    // Super+V: clipboard history over the focused monitor
    ClipboardOverlay {}

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
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
}
