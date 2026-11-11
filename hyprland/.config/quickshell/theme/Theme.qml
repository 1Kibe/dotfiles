pragma Singleton

import QtQuick
import Quickshell

// Colors, sizes and font of the shell. Widgets never hold a color of their
// own: everything comes from here. The choices of Configurações → Aparência
// (accent, transparency, corners, fonts, text size) are written into the
// writable properties below by state/SettingsApply; their defaults are the
// values of today. This file imports nothing of the shell: the login screen
// (greeter) uses it alone and keeps the defaults.
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
    // Windows accent color and a lighter tone of it (active window border);
    // Configurações → Tema e cores (settings/appearance.js accentPair)
    property color accent: "#7e735f"
    property color accentLight: "#bfb8a3"

    // Bar: one strip glued to the top edge, bottom corners rounded.
    // Translucent: Hyprland blurs what is behind it (layer rule
    // "quickshell-bar" in rules.lua). No gradients, no borders.
    // One transparency for the bar and its panels: they are one shape
    // (Configurações → Tema e cores)
    property real barOpacity: 0.85
    readonly property color barFill: root.alpha(bgHard, barOpacity)
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

    // Configurações → Fontes e animações: the families, and the text size as
    // a factor (90–130 %) of the base size
    property string font: "Agave Nerd Font Propo"
    property real textScale: 1
    readonly property int fontSize: Math.round(11 * textScale)

    readonly property int barHeight: 30
    // The general radius (Configurações → Tema e cores) and the bar's bottom
    // corners, which follow it in the same proportion (8 → 12)
    readonly property int barRadius: Math.round(radius * 1.5)
    readonly property int itemHeight: 22
    property int radius: 8                 // tooltips, hover, panels' corners (= decoration.rounding)
    // Corners drawn by a Shape (panels hanging from the bar, the bar's own
    // bottom corners) are "continuous": the curve eases in over (1 + this) ×
    // the radius instead of starting the arc at once (theme/corners.js)
    readonly property real cornerSmoothing: 0.6
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
    property string monoFont: "Agave Nerd Font Mono"

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
    readonly property real lockLockedOpacity: 0.55   // the field while locked out (too many attempts)
    readonly property int spinnerPeriod: 900        // one turn of the "Conferindo…" spinner, ms

    // Login screen (system/greetd/quickshell, which copies this file): the
    // lock's clock, field and status pill, plus the session menu, the user
    // switcher and the power buttons
    readonly property color fg2: "#d5c4a1"                      // the date
    readonly property color loginVeil: root.alpha(bgDeep, 0.55)  // over the background picture
    readonly property color loginPill: root.alpha(bg, 0.88)
    readonly property color loginHighlight: root.alpha(fg, 0.14) // chosen session, hover
    readonly property int loginEdge: 14            // pills from the screen edges
    readonly property int loginSmallText: 12       // session pill, "1 de 2", power hint
    readonly property int loginHintText: 11        // "← → troca de usuário"
    readonly property int loginNameText: 14
    readonly property int loginAvatar: 60
    readonly property int loginNeighbor: 34        // the users beside the current one
    readonly property real loginNeighborOpacity: 0.45
    readonly property int loginNeighborGap: 18
    readonly property int loginChevron: 18
    readonly property int loginChevronGap: 16
    readonly property int loginRing: 2             // outline of the current user
    readonly property int loginFieldWidth: 250
    readonly property int loginFieldHeight: 38
    readonly property int loginSessionMinWidth: 170   // the session list: as wide as its
    readonly property int loginSessionMaxWidth: 260   // longest name, between these
    readonly property int loginPad: 6
    readonly property int loginButton: 34          // suspend, reboot, power off
    readonly property int loginButtonRadius: 10
    readonly property int loginConfirmHeight: 32   // "Clique de novo para desligar"
    readonly property int loginConfirmTimeout: 4000

    // Warning before the idle lock (lock/DimOverlay): veil over every screen
    // and a pill under the bar
    readonly property color idleVeil: Qt.rgba(0, 0, 0, 0.6)
    readonly property int idlePillHeight: 36
    readonly property int idlePillGap: 40      // below the bar
    readonly property int idleTextSize: 15
    readonly property int idleNumberShift: 6   // px each new number slides in from
    readonly property int idleLineHeight: 2    // countdown line under the text
    readonly property int idleLineGap: 5       // from the pill's bottom edge
    readonly property color idleLine: accentLight

    // Lock and login background (lock/BackgroundPicker): defaults of the
    // picker's controls and its sizes
    readonly property real lockBlurDefault: 0.55
    readonly property real lockDarkenDefault: 0.4
    readonly property int pickerWidth: 980
    readonly property int pickerHeight: 600
    readonly property int pickerThumb: 150


    // Normal, yellow or red by load
    function loadColor(value, warn, crit) {
        return value >= crit ? red : value >= warn ? yellow : ringNormal
    }

    // Animations: short, no bounce on panels (the spring is only on items)
    readonly property int animFast: 120     // closing, hover, tooltips
    readonly property int animNormal: 200   // opening, size changes

    // Motion of the panels that hang from the bar (Material 3 values, which
    // are public): durations go through dur(), so one speed scales them all.
    // Speed and "reduce motion" are the settings' (Fontes e animações), set
    // here by state/SettingsApply: 0 = animations off, 0.7 fast, 1 normal,
    // 1.4 calm; reduce motion swaps slides for fades. This file imports
    // nothing of the shell: the login screen (greeter) uses it alone.
    property real speed: 1
    property bool reduceMotion: false
    function dur(ms) {
        return speed <= 0 ? 0 : Math.round(ms * speed)
    }
    readonly property int motionPanelOpen: 300
    // A new track: cover, blurred cover and title crossfade over this
    readonly property int coverFade: 300
    readonly property int motionPanelClose: 200
    // easing.bezierCurve, Material's standard pair (Ryan, 2026-11-10:
    // "Padrão"): opening settles without a jump or a long tail, closing
    // leaves without standing still
    readonly property var curveDecel: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveAccel: [0.4, 0, 1, 1, 1, 1]

    // A panel that touches the screen's left or right edge (the settings,
    // bar/EdgeTimeline): one timeline (Ryan, 2026-11-10, version C, "barra
    // primeiro"): the bar first stretches that end to the screen's edge and
    // squares that corner (the first edgeBarShare of the time), then the
    // panel comes out (from edgePanelFrom to the end), each part with the
    // curve Padrão (curveDecel); closing plays it backwards, shorter
    readonly property int motionEdgeOpen: 450
    readonly property int motionEdgeClose: 300
    readonly property real edgeBarShare: 0.3
    readonly property real edgePanelFrom: 0.2

    // The settings panel (settings/SettingsPanel): on the screen's left edge,
    // from the bar to the bottom, on the timeline above. Its list and cards
    // come in one after another with the expressive curve (a slight
    // overshoot) and leave the other way
    readonly property int settingsWidth: 720
    readonly property int cascadeStart: 160     // after the panel starts opening
    readonly property int cascadeItem: 220      // each item coming in
    readonly property int cascadeStagger: 35    // between two items
    readonly property int cascadeOutItem: 120   // each item leaving
    readonly property int cascadeOutStagger: 12
    readonly property int cascadeShift: 24      // px an item travels coming in
    readonly property int searchFlash: 900      // the found card's highlight
    readonly property var curveExpressive: [0.38, 1.21, 0.22, 1, 1, 1]

    // Room under the bar for the panels when the screen's height is not
    // known yet (Bar.qml takes the rest of the screen)
    readonly property int panelRoom: 480

    // Dates always in Brazilian Portuguese, whatever the system locale
    readonly property var locale: Qt.locale("pt_BR")

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
