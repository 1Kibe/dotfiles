import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
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

    // Super+X and Ctrl+Alt+Del: power menu on the focused monitor's bar
    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                ShellState.toggle("power", monitor.name)
        }
    }

    // Any bar panel on the focused monitor, for keybinds and scripts:
    // qs ipc call panel toggle network   (power, network, volume, bluetooth, media)
    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            const monitor = Hyprland.focusedMonitor
            if (monitor)
                ShellState.toggle(name, monitor.name)
        }
    }
}
