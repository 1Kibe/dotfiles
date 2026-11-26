import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state
import "../settings/validate.js" as Validate

// Desktop wallpaper of the Hyprland session: one layer per monitor, below every
// window. The picture, the screen it goes on and how it fills come from
// Configurações → Papel de parede (SettingsStore: wallpaper, wallpaperMonitor,
// wallpaperFill). A picture is shown only after the same check as the lock's
// picker (BackgroundStore.check: a regular file, no link, up to 30 MB, of real
// type PNG, JPEG or WebP); one that does not pass leaves the repo's default. A
// change fades in over the old picture (WallpaperSwap). Between the check and
// Qt reading it the file could be swapped only in a folder another user can
// write to; the wallpaper folders are this user's own. Nothing on it is
// clickable and it never takes the keyboard. Until the picture loads, or on a
// screen left out, the plain bgDeep shows (the same color as
// misc.background_color in look.lua, which Hyprland paints under everything).
// Session only: the login screen has its own background.
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
        // Being checked (a new picture asked): not settled yet
        property bool checking: false
        // The picture asked is on screen (a change of profile waits for it
        // under the frozen frame, state/SwapState)
        readonly property bool settled: !checking && swapper.settled
        Component.onDestruction: SwapState.removeWallpaper(root)

        function pick() {
            const path = wanted
            if (path === "")
                return
            checking = true
            BackgroundStore.check(path, ok => {
                if (path !== root.wanted)
                    return
                if (ok) {
                    root.shown = path
                    root.checking = false
                } else if (path !== root.fallback) {
                    BackgroundStore.check(root.fallback, ok2 => {
                        if (ok2 && path === root.wanted)
                            root.shown = root.fallback
                        if (path === root.wanted)
                            root.checking = false
                    })
                } else {
                    root.checking = false
                }
            })
        }
        onWantedChanged: pick()
        Component.onCompleted: {
            SwapState.addWallpaper(root)
            pick()
        }

        // A file URL for any name ("#", "?", spaces)
        function fileUrl(path) {
            return "file://" + path.split("/").map(encodeURIComponent).join("/")
        }

        // The picture, changing with a crossfade (a new picture, fill or
        // screen); a screen left out fades to the plain color
        WallpaperSwap {
            id: swapper
            anchors.fill: parent
            instant: SwapState.covering
            source: root.here && root.shown !== "" ? root.fileUrl(root.shown) : ""
            fill: root.fill
        }
    }
}
