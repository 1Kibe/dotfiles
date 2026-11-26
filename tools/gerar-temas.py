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
# project's own terminal theme). None in bgHard: derived from bg.

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
]

FLAVOR_ORDER = ["dark", "darkHard", "darkSoft", "light"]


def flavor(theme, fid):
    f = theme["sabores"][fid]
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
