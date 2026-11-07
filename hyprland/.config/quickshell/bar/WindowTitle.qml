import QtQuick
import Quickshell.Hyprland
import qs.theme

// Title of the focused window, cut with "…". Hidden without a focused window.
BarItem {
    id: root

    // activeToplevel keeps the last window after going to an empty workspace,
    // so only use it while it is on the focused workspace
    readonly property var toplevel: Hyprland.activeToplevel
                                    && Hyprland.activeToplevel.workspace === Hyprland.focusedWorkspace
                                    ? Hyprland.activeToplevel : null
    readonly property string title: toplevel ? toplevel.title : ""
    readonly property string appId: toplevel && toplevel.wayland ? toplevel.wayland.appId : ""

    visible: title !== ""
    clickable: false
    maxWidth: Theme.titleMaxWidth
    text: title
    tooltip: appId !== "" ? `${title}\n${appId}` : title
}
