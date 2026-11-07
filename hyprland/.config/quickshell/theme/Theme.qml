pragma Singleton

import QtQuick
import Quickshell

// Colors, sizes and font of the shell. Widgets never hold a color of their
// own: everything comes from here, so a theme switcher can replace this
// file later.
Singleton {
    id: root

    // Gruvbox dark, same values as hypr/modules/colors.lua
    readonly property color bg: "#282828"
    readonly property color bg1: "#3c3836"
    readonly property color bg2: "#504945"
    readonly property color bgHard: "#1d2021"
    readonly property color bgDeep: "#141617"
    readonly property color fg: "#ebdbb2"
    readonly property color fg4: "#a89984"
    // Text of the bar: plain white for now; the theme switcher will tune it
    readonly property color text: "#ffffff"
    readonly property color gray: "#928374"
    readonly property color yellow: "#fabd2f"
    readonly property color orange: "#fe8019"
    readonly property color red: "#fb4934"
    readonly property color green: "#b8bb26"
    readonly property color aqua: "#8ec07c"
    readonly property color blue: "#83a598"
    // Windows accent color and a lighter tone of it (active window border)
    readonly property color accent: "#7e735f"
    readonly property color accentLight: "#bfb8a3"

    // Bar: one strip glued to the top edge, bottom corners rounded.
    // Translucent: Hyprland blurs what is behind it (layer rule
    // "quickshell-bar" in rules.lua). No gradients, no borders.
    readonly property color barFill: root.alpha(bgHard, 0.85)
    readonly property color veil: root.alpha(fg, 0.08)   // hover
    readonly property color danger: root.alpha(red, 0.18)   // armed power action
    readonly property color clear: root.alpha(bgHard, 0)

    // Workspace dots: empty, with windows, active (a longer dash)
    readonly property color dotEmpty: bg2
    readonly property color dotBusy: fg4
    readonly property color dotActive: accentLight
    readonly property int dotSize: 8
    readonly property int dotActiveWidth: 24

    readonly property string font: "Agave Nerd Font Propo"
    readonly property int fontSize: 11

    readonly property int barHeight: 30
    readonly property int barRadius: 12    // bottom corners of the bar
    readonly property int itemHeight: 22
    readonly property int radius: 8        // tooltips, hover (= decoration.rounding)
    readonly property int gap: 10          // = general.gaps_out (sides of the bar)
    readonly property int padding: 16      // inside the bar, at both ends
    readonly property int spacing: 8
    readonly property int titleMaxWidth: 350
    readonly property int mediaMaxChars: 35
    readonly property int hoverDelay: 500
    readonly property int panelWidth: 300
    readonly property int cardIcon: 32     // icon circle of the device cards

    // Animations: short, no bounce on panels (the spring is only on items)
    readonly property int animFast: 120     // closing, hover, tooltips
    readonly property int animNormal: 200   // opening, size changes

    // Dates always in Brazilian Portuguese, whatever the system locale
    readonly property var locale: Qt.locale("pt_BR")

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
