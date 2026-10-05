"""Builds the team-colour character skins from the KayKit palette textures.

Each KayKit texture is an 8x4 grid of 128x256 gradient cells. We repaint the
cloth cells of each class in the faction colour (keeping the gradient), and
give elves blond hair. Run from the project root:  python3 tools/recolor_skins.py
"""
from PIL import Image
import colorsys, os

SRC = "assets/props/gear"
OUT = "assets/characters/skins"
TEAMS = {
    "elf": {"primary": (0.25, 0.62, 0.32), "secondary": (0.16, 0.42, 0.22), "accent": (0.95, 0.78, 0.25), "hair": (0.93, 0.8, 0.4)},
    "human": {"primary": (0.22, 0.42, 0.85), "secondary": (0.14, 0.26, 0.6), "accent": (0.95, 0.78, 0.25), "hair": None},
}
# (col, row) palette cells per texture: which cells are the main cloth, the
# cape or trim, and the hair.
CELLS = {
    "knight":    {"primary": [(0, 1)], "secondary": [(2, 2)], "hair": [(1, 0)]},
    "rogue":     {"primary": [(0, 1), (1, 1), (1, 2)], "secondary": [(2, 2)], "hair": [(1, 0)]},
    "mage":      {"primary": [(0, 1), (1, 1), (7, 1)], "secondary": [(2, 1), (1, 2)], "hair": [(1, 0), (2, 0)]},
    "barbarian": {"primary": [(0, 1), (1, 1)], "secondary": [(2, 2)], "hair": [(1, 0)]},
}
# Variants that keep their own palette but still take the team colour.
VARIANTS = {
    # The Healer uses the mage model in white and green/blue.
    "healer": ("mage", {"primary": (0.93, 0.92, 0.85), "secondary": "team_primary", "hair": "team_hair"}),
    # Monarchs: the Elf Queen is a rogue in team colours with gold trim, the Human King a barbarian.
    "queen": ("rogue", {"primary": "team_primary", "secondary": (0.95, 0.78, 0.25), "hair": "team_hair"}),
    "king": ("barbarian", {"primary": "team_primary", "secondary": (0.95, 0.78, 0.25), "hair": None}),
}


def recolor_cell(img, col, row, rgb):
    px = img.load()
    x0, y0 = col * 128, row * 256
    # Measure the cell's brightness range so the gradient survives.
    vals = [colorsys.rgb_to_hsv(*[c / 255 for c in px[x, y][:3]])[2] for y in range(y0, y0 + 256, 8) for x in range(x0, x0 + 128, 16)]
    vmax = max(vals) or 1.0
    th, ts, tv = colorsys.rgb_to_hsv(*rgb)
    for y in range(y0, y0 + 256):
        for x in range(x0, x0 + 128):
            r, g, b, *a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            nr, ng, nb = colorsys.hsv_to_rgb(th, ts, min(1.0, tv * (v / vmax) * 1.15))
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255)) + tuple(a)


def build(name, base, team, overrides=None):
    img = Image.open(f"{SRC}/{base}_texture.png").convert("RGBA")
    t = TEAMS[team]
    cells = CELLS[base]
    for part in ("primary", "secondary", "hair"):
        color = t[part] if overrides is None else overrides.get(part, t[part])
        if color == "team_primary":
            color = t["primary"]
        elif color == "team_hair":
            color = t["hair"]
        if color is None:
            continue
        for c, r in cells[part]:
            recolor_cell(img, c, r, color)
    out = f"{OUT}/{name}_{team}.png"
    img.save(out)
    print("wrote", out)


os.makedirs(OUT, exist_ok=True)
for team in TEAMS:
    for base in CELLS:
        build(base, base, team)
    for name, (base, overrides) in VARIANTS.items():
        build(name, base, team, overrides)
