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


# ── The palettes ──
# Per theme: id, name, license entry, the default accent (a palette color; or
# accent and light both given) and its flavors (dark, darkHard, darkSoft)
# with the roles, the 7 named colors and the 8 dark terminal tones (the
# project's own terminal theme). None in bgHard: derived from bg. A role the
# palette has no color for may be written ("mix", a, b, t): a toward b by t,
# both colors of the palette.

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
        },
        "nomeadas": {"yellow": "#dbbc7f", "orange": "#e69875", "red": "#e67e80", "green": "#a7c080",
                     "aqua": "#83c092", "blue": "#7fbbb3", "purple": "#d699b6"},
    },
]

FLAVOR_ORDER = ["dark", "darkHard", "darkSoft", "light"]


def value(v):
    if isinstance(v, tuple) and v[0] == "mix":
        return mix(v[1], v[2], v[3])
    return v


def flavor(theme, fid):
    f = {k: value(v) for k, v in theme["sabores"][fid].items()}
    named = dict(theme.get("nomeadas", {}), **f.get("nomeadas", {}))
    ansi = f.get("ansi", theme.get("ansi"))
    bg_hard = f["bgHard"] if f["bgHard"] else darken(f["bg"], 0.25)
    roles = {
        "bgDeep": darken(bg_hard, 0.3), "bgHard": bg_hard, "bg": f["bg"], "bg1": f["bg1"], "bg2": f["bg2"],
        "fg": f["fg"], "fg2": f["fg2"], "fg4": f["fg4"], "text": f["fg"], "gray": f["gray"],
    }
    return {"rotulo": f["rotulo"], "escuro": True, "syntaxTheme": f["syntaxTheme"], "papeis": roles,
            "nomeadas": {k: named[k] for k in ["yellow", "orange", "red", "green", "aqua", "blue", "purple"]},
            "ansi": list(ansi)}


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
                '      "escuro": true,',
                f'      "syntaxTheme": {q(f["syntaxTheme"])},',
                '      "papeis": {',
                "        " + ", ".join(f'{q(k)}: {q(r[k])}' for k in ["bgDeep", "bgHard", "bg", "bg1", "bg2"]) + ",",
                "        " + ", ".join(f'{q(k)}: {q(r[k])}' for k in ["fg", "fg2", "fg4", "text", "gray"]),
                '      },',
                '      "nomeadas": {',
                "        " + ", ".join(f'{q(k)}: {q(c[k])}' for k in ["yellow", "orange", "red", "green", "aqua"]) + ",",
                "        " + ", ".join(f'{q(k)}: {q(c[k])}' for k in ["blue", "purple"]),
                '      },',
                '      "ansi": [' + ", ".join(q(a) for a in f["ansi"]) + "]",
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
            problems = check(theme, fid, flavor(theme, fid))
            report.append(f"{theme['id']}/{fid}: " + (", ".join(problems) if problems else "contrastes ok"))
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps([t["id"] for t in THEMES]) + "\n")
    print("\n".join(report))
    if any("ok" not in line for line in report):
        sys.exit(1)


if __name__ == "__main__":
    main()
