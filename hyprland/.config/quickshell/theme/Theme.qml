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
    readonly property color purple: "#d3869b"
    // Windows accent color and a lighter tone of it (active window border)
    readonly property color accent: "#7e735f"
    readonly property color accentLight: "#bfb8a3"

    // Bar: one strip glued to the top edge, bottom corners rounded.
    // Translucent: Hyprland blurs what is behind it (layer rule
    // "quickshell-bar" in rules.lua). No gradients, no borders.
    readonly property color barFill: root.alpha(bgHard, 0.85)
    readonly property color veil: root.alpha(fg, 0.08)   // hover
    readonly property color islandFill: root.alpha(bg, 0.9)   // center island while music plays
    readonly property color coverShade: root.alpha(bgHard, 0.55)  // over the blurred cover (island)
    readonly property color panelShade: root.alpha(bgHard, 0.6)   // over the blurred cover (music panel)
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

    // System monitor rings (bar and panel)
    readonly property int ringSize: 20       // in the bar
    readonly property int ringBigSize: 64    // in the panel
    readonly property color ringTrack: bg2
    readonly property color ringNormal: accentLight
    readonly property int usageWarn: 70      // CPU and RAM, percent
    readonly property int usageCrit: 90
    readonly property int tempWarn: 75       // CPU temperature, °C
    readonly property int tempCrit: 90

    // Clipboard overlay (Super+V): dimmed screen, strip at the bottom
    readonly property color dim: Qt.rgba(0, 0, 0, 0.35)
    readonly property color stripFill: root.alpha(bgHard, 0.94)
    readonly property color cardFill: root.alpha(bg1, 0.55)
    readonly property color pinBorder: root.alpha(yellow, 0.75)
    readonly property int stripHeight: 330
    readonly property int stripRadius: 14
    readonly property int cardSize: 200
    readonly property string monoFont: "Agave Nerd Font Mono"

    // Quick notes (post-its above the strip): the 5 colors a note cycles through
    readonly property var noteColors: [yellow, green, blue, orange, purple]
    readonly property color noteInk: bgHard     // text on a post-it
    readonly property color notesFill: root.alpha(bgHard, 0.82)
    readonly property int noteSize: 180
    readonly property int emojiCell: 48     // emoji tab of the strip
    readonly property string emojiFont: "Noto Color Emoji"   // package noto-fonts-emoji

    // Screen capture (Print): bars, buttons, selection handles, card
    readonly property int pillRadius: 14
    readonly property int captureButtonWidth: 30
    readonly property int captureButtonHeight: 28
    readonly property int handleSize: 9
    readonly property int captureCardWidth: 210
    readonly property int countdownSize: 84
    readonly property color activeFill: root.alpha(fg, 0.2)    // chosen button in the capture bars
    readonly property real highlightAlpha: 0.35                // capture marker (highlighter)
    readonly property int blurRadius: 64                       // capture "borrar": strong, text unreadable

    // Lock screen (and the login screen, which copies this file): big clock,
    // user picture, password pill. The lock surface itself is bgDeep, so the
    // screen is covered at once, before the content fades in.
    readonly property int lockClockSize: 64
    readonly property int lockDateSize: 15
    readonly property int lockAvatarSize: 96
    readonly property int lockFieldWidth: 300
    readonly property int lockFieldHeight: 44
    readonly property int lockShake: 10          // px the field moves on a wrong password
    readonly property int lockMediaWidth: 360
    readonly property color lockFieldFill: root.alpha(bgHard, 0.75)
    readonly property color lockPillFill: root.alpha(bgHard, 0.6)

    // Lock and login background (lock/BackgroundPicker): defaults of the
    // picker's controls and its sizes
    readonly property real lockBlurDefault: 0.55
    readonly property real lockDarkenDefault: 0.4
    readonly property int pickerWidth: 980
    readonly property int pickerHeight: 600
    readonly property int pickerThumb: 150

    // Desktop wallpaper of the Hyprland session (wallpaper/Wallpaper.qml), a
    // file in ~/.config/wallpapers; the theme switcher will change it
    readonly property string wallpaper: "wallpaper-padrao.png"

    // Normal, yellow or red by load
    function loadColor(value, warn, crit) {
        return value >= crit ? red : value >= warn ? yellow : ringNormal
    }

    // Animations: short, no bounce on panels (the spring is only on items)
    readonly property int animFast: 120     // closing, hover, tooltips
    readonly property int animNormal: 200   // opening, size changes

    // Dates always in Brazilian Portuguese, whatever the system locale
    readonly property var locale: Qt.locale("pt_BR")

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
