import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme

// Desktop wallpaper of the Hyprland session: one layer per monitor, below
// every window, with the picture of Theme.wallpaper (~/.config/wallpapers,
// linked by stow) cropped to fill. Nothing on it is clickable and it never
// takes the keyboard. Until the picture loads, or if it cannot, the plain
// bgDeep shows (the same color as misc.background_color in look.lua, which
// Hyprland paints under everything). Session only: the login screen has its
// own background.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root

        required property var modelData
        screen: modelData

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.bgDeep
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // A theme switcher changes Theme.wallpaper; the picture follows
        Image {
            anchors.fill: parent
            visible: status === Image.Ready
            source: `file://${Quickshell.env("HOME")}/.config/wallpapers/${Theme.wallpaper}`
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Decoded at the monitor's size, not the file's 3840 px
            sourceSize.width: root.width
            sourceSize.height: root.height
        }
    }
}
