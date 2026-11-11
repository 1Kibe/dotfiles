import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state
import "../settings/validate.js" as Validate

// Desktop wallpaper of the Hyprland session: one layer per monitor, below
// every window. The picture, the screen it goes on and how it fills come
// from Configurações → Papel de parede (SettingsStore: wallpaper,
// wallpaperMonitor, wallpaperFill). A picture is shown only after the same
// check as the lock's picker (BackgroundStore.check: a regular file, no
// link, up to 30 MB, of real type PNG, JPEG or WebP); one that does not pass
// leaves the repo's default. Nothing on it is clickable and it never takes
// the keyboard. Until the picture loads, or on a screen left out, the plain
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

        readonly property string home: Quickshell.env("HOME")
        readonly property bool ready: SettingsStore.ready
        // "" = every screen; else only that one
        readonly property string onlyOn: ready ? SettingsStore.get("wallpaperMonitor") : ""
        readonly property bool here: onlyOn === "" || onlyOn === modelData.name
        readonly property string fill: ready ? SettingsStore.get("wallpaperFill") : "fill"
        readonly property string fallback: Validate.expandPath(SettingsStore.defaults.wallpaper || "~/.config/wallpapers/wallpaper-padrao.png", home)
        readonly property string wanted: ready ? Validate.expandPath(SettingsStore.get("wallpaper"), home) : ""
        // The picture that passed the check ("" until one does)
        property string shown: ""

        function pick() {
            const path = wanted
            if (path === "")
                return
            BackgroundStore.check(path, ok => {
                if (path !== root.wanted)
                    return
                if (ok)
                    root.shown = path
                else if (path !== root.fallback)
                    BackgroundStore.check(root.fallback, ok2 => {
                        if (ok2 && path === root.wanted)
                            root.shown = root.fallback
                    })
            })
        }
        onWantedChanged: pick()
        Component.onCompleted: pick()

        // A file URL for any name ("#", "?", spaces)
        function fileUrl(path) {
            return "file://" + path.split("/").map(encodeURIComponent).join("/")
        }

        Image {
            anchors.fill: parent
            visible: root.here && root.shown !== "" && status === Image.Ready
            source: root.here && root.shown !== "" ? root.fileUrl(root.shown) : ""
            fillMode: root.fill === "fit" ? Image.PreserveAspectFit
                    : root.fill === "center" ? Image.Pad
                    : root.fill === "tile" ? Image.Tile
                    : Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            asynchronous: true
            // Fill and fit: decoded at the monitor's size, not the file's
            // 3840 px; centered and tiled keep the picture's own size
            sourceSize: root.fill === "fill" || root.fill === "fit" ? Qt.size(root.width, root.height) : undefined
        }
    }
}
