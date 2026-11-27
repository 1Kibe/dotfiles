#!/usr/bin/env python3
"""Writes the shell's color themes (hyprland/.config/quickshell/themes/<id>.json
and index.json) from the original palettes below.

Each palette's colors are its project's own values, by their original names;
the licenses are in themes/LICENSES. The roles a palette has no color for are
derived here, always the same way: bgHard a quarter darker than bg when the
palette has no darker background, bgDeep 30% darker than bgHard, text = fg,
and the default accent's light tone mixed 45% toward white (the shell's
accentPair). Run from the repo's root: python3 tools/gerar-temas.py
"""
import json
import math
import os
import sys

OUT = os.path.join("hyprland", ".config", "quickshell", "themes")


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def hexa(c):
    return "#" + "".join(f"{v:02x}" for v in c)


def mix(a, b, t):
    """a toward b by t, rounded like the shell's mix() (Math.round)."""
    pa, pb = rgb(a), rgb(b)
    return hexa([math.floor(x + (y - x) * t + 0.5) for x, y in zip(pa, pb)])


def darken(h, t):
    return mix(h, "#000000", t)


def luminance(h):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


# A darker tone of the same color, for the light flavors: in OKLCH the hue
# kept, the lightness lowered until the contrast with `against` reaches
# `least` (the chroma lowered only to stay in sRGB). The same as the shell's
# theme/palettes.js deepen(), number for number.
def _lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _gam(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def to_oklch(h):
    r, g, b = (_lin(v / 255) for v in rgb(h))
    l = math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s_ = math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s_
    A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s_
    B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s_
    return L, math.sqrt(A * A + B * B), math.atan2(B, A)


def from_oklch(L, C, H):
    A, B = C * math.cos(H), C * math.sin(H)
    l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3
    m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3
    s_ = (L - 0.0894841775 * A - 1.2914855480 * B) ** 3
    c = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s_,
         -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s_,
         -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s_]
    if any(v < -0.0005 or v > 1.0005 for v in c):
        return None
    return hexa([math.floor(min(1, max(0, _gam(min(1, max(0, v))))) * 255 + 0.5) for v in c])


def deepen(h, against, least):
    if contrast(h, against) >= least:
        return h.lower()
    L0, C0, H = to_oklch(h)
    L = L0
    while L >= 0:
        C = C0
        c = from_oklch(L, C, H)
        while c is None and C > 0:
            C = max(0, C - 0.005)
            c = from_oklch(L, C, H)
        if c is not None and contrast(c, against) >= least:
            return c
        L -= 0.005
    return "#000000"


# ── The palettes ──
# Per theme: id, name, license entry, the default accent (a palette color; or
# accent and light both given) and its flavors (dark, darkHard, darkSoft)
# with the roles, the 7 named colors and the 8 dark terminal tones (the
# project's own terminal theme). None in bgHard: derived from bg. A role the
# palette has no color for may be written ("mix", a, b, t): a toward b by t,
# both colors of the palette.

GRUVBOX_FADED = {"yellow": "#b57614", "orange": "#af3a03", "red": "#9d0006", "green": "#79740e",
                 "aqua": "#427b58", "blue": "#076678", "purple": "#8f3f71"}
EVERFOREST_LIGHT = {"yellow": "#dfa000", "orange": "#f57d26", "red": "#f85552", "green": "#8da101",
                    "aqua": "#35a77c", "blue": "#3a94c5", "purple": "#df69ba"}

THEMES = [
    {
        "id": "gruvbox", "nome": "Gruvbox", "licenca": "Gruvbox (MIT)",
        # The shell's accent of today (the Windows one), kept as it is
        "accent": "#7e735f", "light": "#bfb8a3",
        "sabores": {
            "dark": {
                "rotulo": "Dark", "syntaxTheme": "gruvbox-dark",
                "bgHard": "#1d2021", "bg": "#282828", "bg1": "#3c3836", "bg2": "#504945",
                "fg": "#ebdbb2", "fg2": "#d5c4a1", "fg4": "#a89984", "gray": "#928374",
            },
            "darkHard": {
                "rotulo": "Dark Hard", "syntaxTheme": "gruvbox-dark",
                "bgHard": None, "bg": "#1d2021", "bg1": "#3c3836", "bg2": "#504945",
                "fg": "#ebdbb2", "fg2": "#d5c4a1", "fg4": "#a89984", "gray": "#928374",
            },
            "darkSoft": {
                "rotulo": "Dark Soft", "syntaxTheme": "gruvbox-dark",
                "bgHard": "#282828", "bg": "#32302f", "bg1": "#3c3836", "bg2": "#504945",
                "fg": "#ebdbb2", "fg2": "#d5c4a1", "fg4": "#a89984", "gray": "#928374",
            },
            # Light: https://github.com/morhetz/gruvbox (colors/gruvbox.vim)
            # The light ones: bg0, bg0_h, bg0_s by contrast; bg1, bg2; fg1,
            # fg2, fg4, gray; the faded colors; the terminal as the vim file
            # sets it (color0 the background, color7 fg4)
            "light": {
                "rotulo": "Light", "syntaxTheme": "gruvbox-light",
                "bgHard": None, "bg": "#fbf1c7", "bg1": "#ebdbb2", "bg2": "#d5c4a1",
                "fg": "#3c3836", "fg2": "#504945", "fg4": "#7c6f64", "gray": "#928374",
                "nomeadas": GRUVBOX_FADED,
                "ansi": ["#fbf1c7", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#7c6f64"],
            },
            "lightHard": {
                "rotulo": "Light Hard", "syntaxTheme": "gruvbox-light",
                "bgHard": None, "bg": "#f9f5d7", "bg1": "#ebdbb2", "bg2": "#d5c4a1",
                "fg": "#3c3836", "fg2": "#504945", "fg4": "#7c6f64", "gray": "#928374",
                "nomeadas": GRUVBOX_FADED,
                "ansi": ["#f9f5d7", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#7c6f64"],
            },
            "lightSoft": {
                "rotulo": "Light Soft", "syntaxTheme": "gruvbox-light",
                "bgHard": None, "bg": "#f2e5bc", "bg1": "#ebdbb2", "bg2": "#d5c4a1",
                "fg": "#3c3836", "fg2": "#504945", "fg4": "#7c6f64", "gray": "#928374",
                "nomeadas": GRUVBOX_FADED,
                "ansi": ["#f2e5bc", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#7c6f64"],
            },
        },
        "nomeadas": {"yellow": "#fabd2f", "orange": "#fe8019", "red": "#fb4934", "green": "#b8bb26",
                     "aqua": "#8ec07c", "blue": "#83a598", "purple": "#d3869b"},
        # The terminal's dark tones of today (kitty.conf)
        "ansi": ["#1d2021", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#a89984"],
    },
    {
        "id": "catppuccin", "nome": "Catppuccin", "licenca": "Catppuccin (MIT)",
        "accent": "#c6a0f6",   # Macchiato mauve
        "sabores": {
            # base, mantle, surface0, surface1; text, subtext1, subtext0, overlay1
            "dark": {
                "rotulo": "Macchiato", "syntaxTheme": "Catppuccin Macchiato",
                "bgHard": "#1e2030", "bg": "#24273a", "bg1": "#363a4f", "bg2": "#494d64",
                "fg": "#cad3f5", "fg2": "#b8c0e0", "fg4": "#a5adcb", "gray": "#8087a2",
                "nomeadas": {"yellow": "#eed49f", "orange": "#f5a97f", "red": "#ed8796", "green": "#a6da95",
                             "aqua": "#8bd5ca", "blue": "#8aadf4", "purple": "#c6a0f6"},
                "ansi": ["#494d64", "#ed8796", "#a6da95", "#eed49f", "#8aadf4", "#f5bde6", "#8bd5ca", "#a5adcb"],
            },
            "darkHard": {
                "rotulo": "Mocha", "syntaxTheme": "Catppuccin Mocha",
                "bgHard": "#181825", "bg": "#1e1e2e", "bg1": "#313244", "bg2": "#45475a",
                "fg": "#cdd6f4", "fg2": "#bac2de", "fg4": "#a6adc8", "gray": "#7f849c",
                "nomeadas": {"yellow": "#f9e2af", "orange": "#fab387", "red": "#f38ba8", "green": "#a6e3a1",
                             "aqua": "#94e2d5", "blue": "#89b4fa", "purple": "#cba6f7"},
                "ansi": ["#45475a", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8"],
            },
            "darkSoft": {
                "rotulo": "Frappé", "syntaxTheme": "Catppuccin Frappe",
                "bgHard": "#292c3c", "bg": "#303446", "bg1": "#414559", "bg2": "#51576d",
                "fg": "#c6d0f5", "fg2": "#b5bfe2", "fg4": "#a5adce", "gray": "#838ba7",
                "nomeadas": {"yellow": "#e5c890", "orange": "#ef9f76", "red": "#e78284", "green": "#a6d189",
                             "aqua": "#81c8be", "blue": "#8caaee", "purple": "#ca9ee6"},
                "ansi": ["#51576d", "#e78284", "#a6d189", "#e5c890", "#8caaee", "#f4b8e4", "#81c8be", "#a5adce"],
            },
            # Light: https://github.com/catppuccin/palette (palette.json); terminal: https://github.com/catppuccin/kitty (themes/latte.conf)
            "light": {
                "rotulo": "Latte", "syntaxTheme": "Catppuccin Latte",
                "bgHard": "#e6e9ef", "bg": "#eff1f5", "bg1": "#ccd0da", "bg2": "#bcc0cc",
                "fg": "#4c4f69", "fg2": "#5c5f77", "fg4": "#6c6f85", "gray": "#8c8fa1",
                "nomeadas": {"yellow": "#df8e1d", "orange": "#fe640b", "red": "#d20f39", "green": "#40a02b",
                             "aqua": "#179299", "blue": "#1e66f5", "purple": "#8839ef"},
                "ansi": ["#5c5f77", "#d20f39", "#40a02b", "#df8e1d", "#1e66f5", "#ea76cb", "#179299", "#acb0be"],
            },
        },
    },
    {
        "id": "nord", "nome": "Nord", "licenca": "Nord (MIT)",
        "accent": "#88c0d0",   # nord8
        "sabores": {
            # One palette (Polar Night, Snow Storm, Frost, Aurora are its
            # groups, not flavors): nord0-2; nord4, nord5; the dim text
            # between nord3 and nord4 (nord3 alone reads 1.9 on nord0)
            "dark": {
                "rotulo": "Escuro", "syntaxTheme": "Nord",
                "bgHard": None, "bg": "#2e3440", "bg1": "#3b4252", "bg2": "#434c5e",
                "fg": "#d8dee9", "fg2": "#e5e9f0", "fg4": ("mix", "#4c566a", "#d8dee9", 0.5),
                "gray": ("mix", "#4c566a", "#d8dee9", 0.4),
            },
        },
        "nomeadas": {"yellow": "#ebcb8b", "orange": "#d08770", "red": "#bf616a", "green": "#a3be8c",
                     "aqua": "#8fbcbb", "blue": "#81a1c1", "purple": "#b48ead"},
        # Nord's terminal port (nordtheme/alacritty), normal colors
        "ansi": ["#3b4252", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0", "#e5e9f0"],
    },
    {
        "id": "tokyo-night", "nome": "Tokyo Night", "licenca": "Tokyo Night (MIT)",
        "accent": "#7aa2f7",
        "sabores": {
            # The original theme (VS Code): editor background, side bar,
            # active selection, line numbers; editor text, the lighter
            # one, the terminal's white
            "dark": {
                "rotulo": "Night", "syntaxTheme": "base16",
                "bgHard": "#16161e", "bg": "#1a1b26", "bg1": "#202330", "bg2": "#363b54",
                "fg": "#a9b1d6", "fg2": "#9aa5ce", "fg4": "#787c99", "gray": "#787c99",
                "ansi": ["#363b54", "#f7768e", "#73daca", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#787c99"],
            },
            "darkSoft": {
                "rotulo": "Storm", "syntaxTheme": "base16",
                "bgHard": "#1f2335", "bg": "#24283b", "bg1": "#2c324a", "bg2": "#3b4261",
                "fg": "#a9b1d6", "fg2": "#9aa5ce", "fg4": "#8089b3", "gray": "#8089b3",
                "ansi": ["#414868", "#f7768e", "#73daca", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#8089b3"],
            },
            # Light: https://github.com/tokyo-night/tokyo-night-vscode-theme (themes/tokyo-night-light-color-theme.json)
            # Light: editor background, side bar (darker), line highlight, the
            # selection's color without its alpha; the editor text, the
            # parameters' lighter text, the terminal's white, the comments.
            # No orange nor true green in its terminal: the number and the
            # string tokens
            "light": {
                "rotulo": "Light", "syntaxTheme": "OneHalfLight",
                "bgHard": "#d6d8df", "bg": "#e6e7ed", "bg1": "#dcdee3", "bg2": "#acb0bf",
                "fg": "#343b59", "fg2": "#4e5579", "fg4": "#707280", "gray": "#888b94",
                "nomeadas": {"yellow": "#8f5e15", "orange": "#965027", "red": "#8c4351", "green": "#385f0d",
                             "aqua": "#006c86", "blue": "#2959aa", "purple": "#7b43ba"},
                "ansi": ["#343b58", "#8c4351", "#33635c", "#8f5e15", "#2959aa", "#7b43ba", "#006c86", "#707280"],
            },
        },
        "nomeadas": {"yellow": "#e0af68", "orange": "#ff9e64", "red": "#f7768e", "green": "#9ece6a",
                     "aqua": "#73daca", "blue": "#7aa2f7", "purple": "#bb9af7"},
    },
    {
        "id": "everforest", "nome": "Everforest", "licenca": "Everforest (MIT)",
        "accent": "#a7c080",   # green
        "sabores": {
            # bg_dim, bg0, bg1, bg2 of each contrast; fg, grey2, grey1,
            # grey0; the terminal as the theme sets it (bg3 for black)
            "dark": {
                "rotulo": "Dark Medium", "syntaxTheme": "base16",
                "bgHard": "#232a2e", "bg": "#2d353b", "bg1": "#343f44", "bg2": "#3d484d",
                "fg": "#d3c6aa", "fg2": "#9da9a0", "fg4": "#859289", "gray": "#7a8478",
                "ansi": ["#475258", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa"],
            },
            "darkHard": {
                "rotulo": "Dark Hard", "syntaxTheme": "base16",
                "bgHard": "#1e2326", "bg": "#272e33", "bg1": "#2e383c", "bg2": "#374145",
                "fg": "#d3c6aa", "fg2": "#9da9a0", "fg4": "#859289", "gray": "#7a8478",
                "ansi": ["#414b50", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa"],
            },
            "darkSoft": {
                "rotulo": "Dark Soft", "syntaxTheme": "base16",
                "bgHard": "#293136", "bg": "#333c43", "bg1": "#3a464c", "bg2": "#434f55",
                "fg": "#d3c6aa", "fg2": "#9da9a0", "fg4": "#859289", "gray": "#7a8478",
                "ansi": ["#4d5960", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa"],
            },
            # Light: https://github.com/sainnhe/everforest (autoload/everforest.vim; terminal: colors/everforest.vim)
            "light": {
                "rotulo": "Light Medium", "syntaxTheme": "base16",
                "bgHard": "#efebd4", "bg": "#fdf6e3", "bg1": "#f4f0d9", "bg2": "#efebd4",
                "fg": "#5c6a72", "fg2": "#829181", "fg4": "#939f91", "gray": "#a6b0a0",
                "nomeadas": EVERFOREST_LIGHT,
                "ansi": ["#5c6a72", "#f85552", "#8da101", "#dfa000", "#3a94c5", "#df69ba", "#35a77c", "#e6e2cc"],
            },
            "lightHard": {
                "rotulo": "Light Hard", "syntaxTheme": "base16",
                "bgHard": "#f2efdf", "bg": "#fffbef", "bg1": "#f8f5e4", "bg2": "#f2efdf",
                "fg": "#5c6a72", "fg2": "#829181", "fg4": "#939f91", "gray": "#a6b0a0",
                "nomeadas": EVERFOREST_LIGHT,
                "ansi": ["#5c6a72", "#f85552", "#8da101", "#dfa000", "#3a94c5", "#df69ba", "#35a77c", "#edeada"],
            },
            "lightSoft": {
                "rotulo": "Light Soft", "syntaxTheme": "base16",
                "bgHard": "#e5dfc5", "bg": "#f3ead3", "bg1": "#eae4ca", "bg2": "#e5dfc5",
                "fg": "#5c6a72", "fg2": "#829181", "fg4": "#939f91", "gray": "#a6b0a0",
                "nomeadas": EVERFOREST_LIGHT,
                "ansi": ["#5c6a72", "#f85552", "#8da101", "#dfa000", "#3a94c5", "#df69ba", "#35a77c", "#ddd8be"],
            },
        },
        "nomeadas": {"yellow": "#dbbc7f", "orange": "#e69875", "red": "#e67e80", "green": "#a7c080",
                     "aqua": "#83c092", "blue": "#7fbbb3", "purple": "#d699b6"},
    },
    {
        "id": "rose-pine", "nome": "Rosé Pine", "licenca": "Rosé Pine (MIT)",
        "accent": "#c4a7e7",   # iris
        "sabores": {
            # base, surface, overlay; text, subtle, muted. Six accents for
            # seven names: green and blue as the project's own terminal has
            # them (pine, foam), orange the nearest (rose), aqua = foam
            "dark": {
                "rotulo": "Main", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#191724", "bg1": "#1f1d2e", "bg2": "#26233a",
                "fg": "#e0def4", "fg2": "#908caa", "fg4": "#6e6a86", "gray": "#6e6a86",
                "nomeadas": {"yellow": "#f6c177", "orange": "#ebbcba", "red": "#eb6f92", "green": "#31748f",
                             "aqua": "#9ccfd8", "blue": "#9ccfd8", "purple": "#c4a7e7"},
                "ansi": ["#26233a", "#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba", "#e0def4"],
            },
            "darkSoft": {
                "rotulo": "Moon", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#232136", "bg1": "#2a273f", "bg2": "#393552",
                "fg": "#e0def4", "fg2": "#908caa", "fg4": "#6e6a86", "gray": "#6e6a86",
                "nomeadas": {"yellow": "#f6c177", "orange": "#ea9a97", "red": "#eb6f92", "green": "#3e8fb0",
                             "aqua": "#9ccfd8", "blue": "#9ccfd8", "purple": "#c4a7e7"},
                "ansi": ["#393552", "#eb6f92", "#3e8fb0", "#f6c177", "#9ccfd8", "#c4a7e7", "#ea9a97", "#e0def4"],
            },
            # Light: https://github.com/rose-pine/palette (dist/index.js); terminal: https://github.com/rose-pine/kitty (dist/rose-pine-dawn.conf)
            # Dawn: base; overlay and highlightMed as the two surfaces (its
            # surface is lighter than base); text, subtle, muted; the named
            # ones as in the dark ones
            "light": {
                "rotulo": "Dawn", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#faf4ed", "bg1": "#f2e9e1", "bg2": "#dfdad9",
                "fg": "#575279", "fg2": "#797593", "fg4": "#9893a5", "gray": "#9893a5",
                "nomeadas": {"yellow": "#ea9d34", "orange": "#d7827e", "red": "#b4637a", "green": "#286983",
                             "aqua": "#56949f", "blue": "#56949f", "purple": "#907aa9"},
                "ansi": ["#f2e9e1", "#b4637a", "#286983", "#ea9d34", "#56949f", "#907aa9", "#d7827e", "#575279"],
            },
        },
    },
    {
        "id": "kanagawa", "nome": "Kanagawa", "licenca": "Kanagawa (MIT)",
        "accent": "#7e9cd8",   # crystalBlue
        "sabores": {
            # Each theme's bg_dim, bg, bg_p1, bg_p2 and its text tones; the
            # terminal as each theme sets it (term)
            "dark": {
                "rotulo": "Wave", "syntaxTheme": "base16",
                "bgHard": "#181820", "bg": "#1f1f28", "bg1": "#2a2a37", "bg2": "#363646",
                "fg": "#dcd7ba", "fg2": "#c8c093", "fg4": "#727169", "gray": "#717c7c",
                "nomeadas": {"yellow": "#e6c384", "orange": "#ffa066", "red": "#e46876", "green": "#98bb6c",
                             "aqua": "#7aa89f", "blue": "#7e9cd8", "purple": "#957fb8"},
                "ansi": ["#16161d", "#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589", "#c8c093"],
            },
            "darkHard": {
                "rotulo": "Dragon", "syntaxTheme": "base16",
                "bgHard": "#12120f", "bg": "#181616", "bg1": "#282727", "bg2": "#393836",
                "fg": "#c5c9c5", "fg2": "#a6a69c", "fg4": "#7a8382", "gray": "#737c73",
                "nomeadas": {"yellow": "#c4b28a", "orange": "#b6927b", "red": "#c4746e", "green": "#87a987",
                             "aqua": "#8ea4a2", "blue": "#8ba4b0", "purple": "#a292a3"},
                "ansi": ["#0d0c0c", "#c4746e", "#8a9a7b", "#c4b28a", "#8ba4b0", "#a292a3", "#8ea4a2", "#c8c093"],
            },
            # Light: https://github.com/rebelot/kanagawa.nvim (lua/kanagawa/colors.lua, lua/kanagawa/themes.lua)
            "light": {
                "rotulo": "Lotus", "syntaxTheme": "base16",
                "bgHard": "#dcd5ac", "bg": "#f2ecbc", "bg1": "#e7dba0", "bg2": "#e4d794",
                "fg": "#545464", "fg2": "#43436c", "fg4": "#716e61", "gray": "#8a8980",
                "nomeadas": {"yellow": "#77713f", "orange": "#cc6d00", "red": "#c84053", "green": "#6f894e",
                             "aqua": "#597b75", "blue": "#4d699b", "purple": "#624c83"},
                "ansi": ["#1f1f28", "#c84053", "#6f894e", "#77713f", "#4d699b", "#b35b79", "#597b75", "#545464"],
            },
        },
    },
    {
        "id": "cyberdream", "nome": "Cyberdream", "licenca": "Cyberdream (MIT)",
        "accent": "#5ea1ff",   # blue
        "sabores": {
            # bg, bg_alt, bg_highlight; fg and its one grey (the second
            # text tone between them)
            "dark": {
                "rotulo": "Default", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#16181a", "bg1": "#1e2124", "bg2": "#3c4048",
                "fg": "#ffffff", "fg2": ("mix", "#ffffff", "#7b8496", 0.3), "fg4": "#7b8496", "gray": "#7b8496",
            },
            # Light: https://github.com/scottmckendry/cyberdream.nvim (lua/cyberdream/colors.lua; terminal: extras/kitty/cyberdream-light.conf)
            "light": {
                "rotulo": "Light", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#ffffff", "bg1": "#eaeaea", "bg2": "#acacac",
                "fg": "#16181a", "fg2": ("mix", "#16181a", "#7b8496", 0.5), "fg4": "#7b8496", "gray": "#7b8496",
                "nomeadas": {"yellow": "#997b00", "orange": "#d17c00", "red": "#d11500", "green": "#008b0c",
                             "aqua": "#008c99", "blue": "#0057d1", "purple": "#a018ff"},
                "ansi": ["#ffffff", "#d11500", "#008b0c", "#997b00", "#0057d1", "#a018ff", "#008c99", "#16181a"],
            },
        },
        "nomeadas": {"yellow": "#f1ff5e", "orange": "#ffbd5e", "red": "#ff6e5e", "green": "#5eff6c",
                     "aqua": "#5ef1ff", "blue": "#5ea1ff", "purple": "#bd5eff"},
        # The project's own Kitty theme (extras/kitty/cyberdream.conf)
        "ansi": ["#16181a", "#ff6e5e", "#5eff6c", "#f1ff5e", "#5ea1ff", "#bd5eff", "#5ef1ff", "#ffffff"],
    },
    {
        "id": "flexoki", "nome": "Flexoki", "licenca": "Flexoki (MIT)",
        "accent": "#3aa99f",   # cyan-400
        "sabores": {
            # black, base-950, base-900; base-200, base-300, base-500,
            # base-600; the accents in their 400 tones (the dark theme's)
            "dark": {
                "rotulo": "Dark", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#100f0f", "bg1": "#1c1b1a", "bg2": "#282726",
                "fg": "#cecdc3", "fg2": "#b7b5ac", "fg4": "#878580", "gray": "#6f6e69",
            },
            # Light: https://github.com/kepano/flexoki (README.md; terminal: kitty/flexoki_light.conf)
            # Light: paper, base-50, base-100; black, base-800, base-600,
            # base-500; the accents in their 600 tones (the light theme's)
            "light": {
                "rotulo": "Light", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#fffcf0", "bg1": "#f2f0e5", "bg2": "#e6e4d9",
                "fg": "#100f0f", "fg2": "#403e3c", "fg4": "#6f6e69", "gray": "#878580",
                "nomeadas": {"yellow": "#ad8301", "orange": "#bc5215", "red": "#af3029", "green": "#66800b",
                             "aqua": "#24837b", "blue": "#205ea6", "purple": "#5e409d"},
                "ansi": ["#100f0f", "#d14d41", "#879a39", "#d0a215", "#4385be", "#ce5d97", "#3aa99f", "#fffcf0"],
            },
        },
        "nomeadas": {"yellow": "#d0a215", "orange": "#da702c", "red": "#d14d41", "green": "#879a39",
                     "aqua": "#3aa99f", "blue": "#4385be", "purple": "#8b7ec8"},
        # The project's own Kitty theme (kitty/flexoki_dark.conf)
        "ansi": ["#100f0f", "#af3029", "#66800b", "#ad8301", "#205ea6", "#a02f6f", "#24837b", "#878580"],
    },
    {
        "id": "dracula", "nome": "Dracula", "licenca": "Dracula (MIT)",
        "accent": "#bd93f9",   # Purple
        "sabores": {
            # Background, the Kitty theme's darker one, Current Line (and
            # the tone between them); Foreground, Comment. No blue in the
            # palette: Purple, as the project's Kitty theme has it
            "dark": {
                "rotulo": "Dracula", "syntaxTheme": "Dracula",
                "bgHard": "#21222c", "bg": "#282a36", "bg1": ("mix", "#282a36", "#44475a", 0.5), "bg2": "#44475a",
                "fg": "#f8f8f2", "fg2": ("mix", "#f8f8f2", "#6272a4", 0.25), "fg4": "#6272a4", "gray": "#6272a4",
            },
            # Alucard: Background; bglighter (alucard.vim) and Selection as
            # the surfaces (its Current Line equals Comment, a dark tone);
            # Foreground, Comment; blue = Purple as in the dark one; the
            # project's terminal theme (dracula/foot, alucard.diff:
            # https://github.com/dracula/foot)
            "light": {
                "rotulo": "Alucard", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#fffbeb", "bg1": "#ece9df", "bg2": "#cfcfde",
                "fg": "#1f1f1f", "fg2": ("mix", "#1f1f1f", "#6c664b", 0.5), "fg4": "#6c664b", "gray": "#6c664b",
                "nomeadas": {"yellow": "#846e15", "orange": "#a34d14", "red": "#cb3a2a", "green": "#14710a",
                             "aqua": "#036a96", "blue": "#644ac9", "purple": "#644ac9"},
                "ansi": ["#fffbeb", "#cb3a2a", "#14710a", "#846e15", "#644ac9", "#a3144d", "#036a96", "#1f1f1f"],
            },
        },
        "nomeadas": {"yellow": "#f1fa8c", "orange": "#ffb86c", "red": "#ff5555", "green": "#50fa7b",
                     "aqua": "#8be9fd", "blue": "#bd93f9", "purple": "#bd93f9"},
        # The project's Kitty theme (dracula/kitty)
        "ansi": ["#21222c", "#ff5555", "#50fa7b", "#f1fa8c", "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2"],
    },
    {
        "id": "solarized", "nome": "Solarized", "licenca": "Solarized (MIT)",
        "accent": "#268bd2",   # blue
        "sabores": {
            # base03, base02 (and the tone between it and base01); base0,
            # base1, base00 as the dim text (base01 reads under 3 on
            # base03), base01
            "dark": {
                "rotulo": "Dark", "syntaxTheme": "Solarized (dark)",
                "bgHard": None, "bg": "#002b36", "bg1": "#073642", "bg2": ("mix", "#073642", "#586e75", 0.35),
                "fg": "#839496", "fg2": "#93a1a1", "fg4": "#657b83", "gray": "#586e75",
            },
            # Light: https://github.com/altercation/solarized (README.md; terminal: xresources/solarized)
            # Light: base3, base2 (and a tone toward base1, the palette has
            # none); base00, base01, base0, base1; the Xresources' light block
            "light": {
                "rotulo": "Light", "syntaxTheme": "Solarized (light)",
                "bgHard": None, "bg": "#fdf6e3", "bg1": "#eee8d5", "bg2": ("mix", "#eee8d5", "#93a1a1", 0.35),
                "fg": "#657b83", "fg2": "#586e75", "fg4": "#839496", "gray": "#93a1a1",
                "nomeadas": {"yellow": "#b58900", "orange": "#cb4b16", "red": "#dc322f", "green": "#859900",
                             "aqua": "#2aa198", "blue": "#268bd2", "purple": "#6c71c4"},
                "ansi": ["#eee8d5", "#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198", "#073642"],
            },
        },
        "nomeadas": {"yellow": "#b58900", "orange": "#cb4b16", "red": "#dc322f", "green": "#859900",
                     "aqua": "#2aa198", "blue": "#268bd2", "purple": "#6c71c4"},
        # The project's Xresources (xresources/solarized)
        "ansi": ["#073642", "#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198", "#eee8d5"],
    },
    {
        "id": "neofusion", "nome": "Neofusion", "licenca": "Neofusion (MIT)",
        "accent": "#66def9",   # neutral_aqua
        "sabores": {
            # dark0-2; the palette's text (bright_blue, a beige) and the dim
            # tones toward its gray. Its names do not match its colors: the
            # named ones by color (orange, yellow and green the nearest)
            "dark": {
                "rotulo": "Escuro", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#06101e", "bg1": "#031b26", "bg2": "#052839",
                "fg": "#e2d9c5", "fg2": ("mix", "#e2d9c5", "#22536f", 0.25), "fg4": ("mix", "#e2d9c5", "#22536f", 0.55),
                "gray": ("mix", "#e2d9c5", "#22536f", 0.6),
            },
        },
        "nomeadas": {"yellow": "#98971a", "orange": "#fa7a61", "red": "#fd5e3a", "green": "#5f6e29",
                     "aqua": "#66def9", "blue": "#35b5ff", "purple": "#ec30ac"},
        # The project's Kitty theme (diegoulloao/neofusion.kitty)
        "ansi": ["#0e0807", "#ea6847", "#ea6847", "#5db2f8", "#2f516c", "#d943a8", "#86dbf5", "#e0d9c7"],
    },
    {
        "id": "oxocarbon", "nome": "Oxocarbon", "licenca": "Oxocarbon (MIT)",
        "accent": "#78a9ff",   # base09
        "sabores": {
            # base00; base01-02, the theme's own blends of base00 toward
            # base06 (in HSLuv, so for these grays a straight step of
            # lightness): 0.085 and 0.18; base04 as the text, base05; the dim
            # text between base03 (0.3) and base04. No yellow anywhere in the
            # palette: the light theme's orange as orange and as yellow; the
            # red is base10
            "dark": {
                "rotulo": "Escuro", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#161616", "bg1": "#262626", "bg2": "#393939",
                "fg": "#d0d0d0", "fg2": "#f2f2f2", "fg4": ("mix", "#525252", "#d0d0d0", 0.5),
                "gray": ("mix", "#525252", "#d0d0d0", 0.4),
            },
            # Light: https://github.com/nyoom-engineering/oxocarbon.nvim (fnl/oxocarbon/init.fnl)
            # Light: base00, and base01-02 by the theme's own blends (0.95,
            # 0.82 toward base03); base04 the text, base06, base05. No yellow
            # nor true red: base10 (orange) as both, base09 as red. Its
            # terminal reuses the dark slots (red would be blue): the named
            # ones in their places
            "light": {
                "rotulo": "Claro", "syntaxTheme": "base16",
                "bgHard": None, "bg": "#ffffff", "bg1": "#f2f2f2", "bg2": "#d0d0d0",
                "fg": "#37474f", "fg2": "#525252", "fg4": "#90a4ae", "gray": "#90a4ae",
                "nomeadas": {"yellow": "#ff6f00", "orange": "#ff6f00", "red": "#ee5396", "green": "#42be65",
                             "aqua": "#08bdba", "blue": "#0f62fe", "purple": "#673ab7"},
                "ansi": ["#f2f2f2", "#ee5396", "#42be65", "#ff6f00", "#0f62fe", "#673ab7", "#08bdba", "#37474f"],
            },
        },
        "nomeadas": {"yellow": "#ff6f00", "orange": "#ff6f00", "red": "#ee5396", "green": "#42be65",
                     "aqua": "#08bdba", "blue": "#78a9ff", "purple": "#be95ff"},
        # The theme's terminal colors (terminal_color_0-7)
        "ansi": ["#262626", "#33b1ff", "#be95ff", "#42be65", "#78a9ff", "#82cfff", "#3ddbd9", "#f2f2f2"],
    },
]

FLAVOR_ORDER = ["dark", "darkHard", "darkSoft", "light", "lightHard", "lightSoft"]


def value(v):
    if isinstance(v, tuple) and v[0] == "mix":
        return mix(v[1], v[2], v[3])
    return v


def flavor(theme, fid):
    f = {k: value(v) for k, v in theme["sabores"][fid].items()}
    named = dict(theme.get("nomeadas", {}), **f.get("nomeadas", {}))
    ansi = f.get("ansi", theme.get("ansi"))
    dark = fid.startswith("dark")
    # (light ones: the background behind is a little darker, as the light
    # palettes have it: Catppuccin's mantle, Everforest's bg_dim)
    bg_hard = f["bgHard"] if f["bgHard"] else darken(f["bg"], 0.25 if dark else 0.05)
    roles = {
        "bgDeep": darken(bg_hard, 0.3 if dark else 0.08), "bgHard": bg_hard, "bg": f["bg"], "bg1": f["bg1"], "bg2": f["bg2"],
        "fg": f["fg"], "fg2": f["fg2"], "fg4": f["fg4"], "text": f["fg"], "gray": f["gray"],
    }
    named = {k: named[k] for k in ["yellow", "orange", "red", "green", "aqua", "blue", "purple"]}
    adjusted = []
    if not dark:
        # (the shell's copy only: the terminal keeps the palette's own)
        def darker(a, b):
            return a if luminance(a) < luminance(b) else b
        for k in named:
            n = deepen(named[k], roles["bg"], 3)
            if n != named[k].lower():
                adjusted.append(f"{k} {named[k]}->{n}")
            named[k] = n
        for k in ("fg4", "gray"):
            n = deepen(roles[k], darker(roles["bg"], roles["bg1"]), 3)
            if n != roles[k].lower():
                adjusted.append(f"{k} {roles[k]}->{n}")
            roles[k] = n
        n = deepen(roles["fg"], darker(roles["bg"], roles["bgHard"]), 4.5)
        if n != roles["fg"].lower():
            adjusted.append(f"fg {roles['fg']}->{n}")
        roles["fg"] = roles["text"] = n
    out = {"rotulo": f["rotulo"], "escuro": dark, "syntaxTheme": f["syntaxTheme"], "papeis": roles,
           "nomeadas": named, "ansi": list(ansi), "ajustes": adjusted}
    # A light flavor's default accent: when the theme's is a color of its
    # dark palette, the same color of the light one (and its darker tone)
    if not dark:
        darkp = dict(theme.get("nomeadas", {}), **theme["sabores"][next(i for i in FLAVOR_ORDER if i in theme["sabores"])].get("nomeadas", {}))
        name = next((k for k, v in darkp.items() if v.lower() == theme["accent"].lower()), None)
        if name:
            acc = named[name]
            out["destaque"] = {"accent": acc, "light": deepen(acc, roles["bg"], 4.5)}
    return out


def check(theme, fid, f):
    """The spec's contrasts (fg/bg 4.5, fg4/bg 3, text/bgHard 4.5, each named/bg 3)."""
    r, problems = f["papeis"], []
    for name, a, b, least in [("fg/bg", r["fg"], r["bg"], 4.5), ("fg4/bg", r["fg4"], r["bg"], 3),
                              ("text/bgHard", r["text"], r["bgHard"], 4.5)]:
        if contrast(a, b) < least:
            problems.append(f"{name} {contrast(a, b):.2f}")
    for k, v in f["nomeadas"].items():
        if contrast(v, r["bg"]) < 3:
            problems.append(f"{k}/bg {contrast(v, r['bg']):.2f}")
    return problems


def text(theme):
    """The file, laid out like the first one (gruvbox.json)."""
    q = json.dumps
    out = ["{", '  "versao": 1,', f'  "id": {q(theme["id"])},', f'  "nome": {q(theme["nome"], ensure_ascii=False)},',
           f'  "licenca": {q(theme["licenca"], ensure_ascii=False)},']
    light = theme.get("light") or mix(theme["accent"], "#ffffff", 0.45)
    out.append(f'  "destaquePadrao": {{ "accent": {q(theme["accent"])}, "light": {q(light)} }},')
    out.append('  "sabores": {')
    ids = [i for i in FLAVOR_ORDER if i in theme["sabores"]]
    for n, fid in enumerate(ids):
        f = flavor(theme, fid)
        r, c = f["papeis"], f["nomeadas"]
        out += [f'    {q(fid)}: {{',
                f'      "rotulo": {q(f["rotulo"], ensure_ascii=False)},',
                '      "escuro": ' + ("true" if f["escuro"] else "false") + ',',
                f'      "syntaxTheme": {q(f["syntaxTheme"])},',
                '      "papeis": {',
                "        " + ", ".join(f'{q(k)}: {q(r[k])}' for k in ["bgDeep", "bgHard", "bg", "bg1", "bg2"]) + ",",
                "        " + ", ".join(f'{q(k)}: {q(r[k])}' for k in ["fg", "fg2", "fg4", "text", "gray"]),
                '      },',
                '      "nomeadas": {',
                "        " + ", ".join(f'{q(k)}: {q(c[k])}' for k in ["yellow", "orange", "red", "green", "aqua"]) + ",",
                "        " + ", ".join(f'{q(k)}: {q(c[k])}' for k in ["blue", "purple"]),
                '      },',
                '      "ansi": [' + ", ".join(q(a) for a in f["ansi"]) + "]"
                + (f',\n      "destaque": {{ "accent": {q(f["destaque"]["accent"])}, "light": {q(f["destaque"]["light"])} }}' if "destaque" in f else ""),
                "    }" + ("," if n < len(ids) - 1 else "")]
    out += ["  }", "}"]
    return "\n".join(out) + "\n"


def main():
    if not os.path.isdir(OUT):
        sys.exit(f"rodar da raiz do repo (falta {OUT})")
    report = []
    for theme in THEMES:
        with open(os.path.join(OUT, theme["id"] + ".json"), "w", encoding="utf-8") as fh:
            fh.write(text(theme))
        for fid in theme["sabores"]:
            f = flavor(theme, fid)
            problems = check(theme, fid, f)
            note = (" (escurecidos no shell: " + "; ".join(f["ajustes"]) + ")") if f["ajustes"] else ""
            report.append(f"{theme['id']}/{fid}: " + (", ".join(problems) if problems else "contrastes ok") + note)
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps([t["id"] for t in THEMES]) + "\n")
    print("\n".join(report))
    if any("contrastes ok" not in line for line in report):
        sys.exit(1)


if __name__ == "__main__":
    main()
