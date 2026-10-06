"""Generates the game's stylized, tileable PBR textures with numpy + PIL.

Painted-looking stone blocks, cobbles, planks, bark, grass and a dirt road,
each with a normal map made from its height. Everything is light and low in
contrast so game code can tint it per team. Run from the project root:
    python3 tools/make_textures.py
"""
import numpy as np
from PIL import Image, ImageFilter
import os

OUT = "assets/textures"
N = 1024
rng = np.random.default_rng(7)


def lerp(a, b, t):
    return a + (b - a) * t


def value_noise(size, cells, seed):
    """Tileable value noise: a random grid, smoothly interpolated."""
    r = np.random.default_rng(seed)
    g = r.random((cells, cells))
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) * (cells / size)
    x0 = np.floor(xs).astype(int)
    y0 = np.floor(ys).astype(int)
    fx = xs - x0
    fy = ys - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x1 = (x0 + 1) % cells
    y1 = (y0 + 1) % cells
    x0 %= cells
    y0 %= cells
    top = lerp(g[y0, x0], g[y0, x1], fx)
    bot = lerp(g[y1, x0], g[y1, x1], fx)
    return lerp(top, bot, fy)


def fbm(size, base_cells, octaves, seed, gain=0.5):
    out = np.zeros((size, size))
    amp = 1.0
    total = 0.0
    cells = base_cells
    for i in range(octaves):
        out += value_noise(size, cells, seed + i * 31) * amp
        total += amp
        amp *= gain
        cells *= 2
    return out / total


def normal_map(height, strength=2.0):
    """OpenGL-style normal map (Godot's convention) from a 0..1 height field."""
    h = height * strength
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    nx = -dx
    ny = dy
    nz = np.ones_like(h) * (2.0 / N) * 40.0
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, color, height, strength=2.0):
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(f"{OUT}/{name}_color.jpg", quality=92)
    Image.fromarray(normal_map(height, strength)).save(f"{OUT}/{name}_normal.jpg", quality=92)
    print("wrote", name)


def rgb(r, g, b):
    return np.array([r, g, b])


def paint(shape_fn):
    pass


# --- Stone blocks ------------------------------------------------------------

def brick_layout(rows, cols, mortar, bevel, jitter_seed=1):
    """Height map of staggered blocks: 1 on top of a block, falling to 0 in the mortar.
    Also returns an id map so each block can take its own shade."""
    r = np.random.default_rng(jitter_seed)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    row_h = N / rows
    col_w = N / cols
    row = np.floor(ys / row_h)
    offset = (row % 2) * col_w * 0.5
    col = np.floor((xs + offset) / col_w)
    # Position inside the block, 0..1.
    u = ((xs + offset) % col_w) / col_w
    v = (ys % row_h) / row_h
    # Distance to the nearest edge, in block fractions.
    du = np.minimum(u, 1 - u) * col_w
    dv = np.minimum(v, 1 - v) * row_h
    d = np.minimum(du, dv)
    height = np.clip((d - mortar) / bevel, 0, 1)
    height = height * height * (3 - 2 * height)
    ids = (row * 1000 + col).astype(int)
    shade = r.random(int(ids.max()) + 1)[ids]
    return height, shade


def make_stone():
    """Cream sandstone ashlar: big clean blocks with soft bevels and a warm
    mortar line, the castle stone in the renders (both castles use it).
    Also saves stone_moss: the same blocks with moss in the joints and ivy
    for the elven castle."""
    height, shade = brick_layout(rows=6, cols=4, mortar=5, bevel=22)
    grain = fbm(N, 12, 4, 11)
    chips = fbm(N, 64, 2, 12)
    h = height * (0.9 + 0.1 * grain) - 0.05 * (chips > 0.78) * height
    light = rgb(0.93, 0.87, 0.74)
    mid = rgb(0.84, 0.76, 0.60)
    deep = rgb(0.76, 0.66, 0.50)
    color = lerp(deep, light, (0.35 + 0.65 * shade)[..., None])
    color = lerp(color, mid, np.clip(grain * 0.8, 0, 1)[..., None] * 0.5)
    mortar = rgb(0.62, 0.53, 0.40)
    color = lerp(mortar, color, np.clip(height * 1.4, 0, 1)[..., None])
    # A faint painted highlight along each block's top edge.
    ys = np.mgrid[0:N, 0:N][0].astype(np.float64)
    row_v = (ys % (N / 6)) / (N / 6)
    top_edge = np.clip(1 - np.abs(row_v - 0.12) / 0.08, 0, 1) * height
    color = lerp(color, rgb(0.98, 0.94, 0.84), (top_edge * 0.35)[..., None])
    # Weathering: a few chipped corners and faint water stains.
    stain = np.clip((fbm(N, 5, 3, 14) - 0.55) * 4, 0, 1) * height
    color = lerp(color, rgb(0.70, 0.62, 0.48), (stain * 0.35)[..., None])
    save("stone", color, h, 2.0)
    # Mossy variant: moss creeping out of the joints and ivy patches.
    moss_mask = np.clip((1 - height) * 1.2 + (fbm(N, 7, 3, 15) - 0.6) * 2.0, 0, 1) * (fbm(N, 4, 2, 16) > 0.55)
    mossy = lerp(color, rgb(0.40, 0.58, 0.28), np.clip(moss_mask * 0.6, 0, 1)[..., None])
    ivy = (fbm(N, 10, 3, 17) > 0.74) & (fbm(N, 3, 2, 18) > 0.58)
    leaf_tone = lerp(rgb(0.30, 0.50, 0.22), rgb(0.52, 0.72, 0.30), fbm(N, 40, 2, 19)[..., None])
    mossy = lerp(mossy, leaf_tone, ivy[..., None] * 0.95)
    h_moss = h + 0.08 * ivy
    save("stone_moss", mossy, np.clip(h_moss, 0, 1), 2.0)


def make_cobble():
    r = np.random.default_rng(3)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    cells = 12
    cw = N / cells
    height = np.zeros((N, N))
    ids = np.zeros((N, N), dtype=int)
    best = np.full((N, N), 1e9)
    # Jittered grid of rounded stones, checked against neighbouring cells so it tiles.
    centers = {}
    for cy in range(cells):
        for cx in range(cells):
            centers[(cy, cx)] = ((cx + 0.5 + r.uniform(-0.3, 0.3)) * cw, (cy + 0.5 + r.uniform(-0.3, 0.3)) * cw,
                r.uniform(0.52, 0.66) * cw)
    for cy in range(cells):
        for cx in range(cells):
            px, py, rad = centers[(cy, cx)]
            for oy in (-N, 0, N):
                for ox in (-N, 0, N):
                    d = np.sqrt((xs - px - ox) ** 2 + (ys - py - oy) ** 2)
                    closer = d < best
                    best = np.where(closer, d, best)
                    ids = np.where(closer, cy * cells + cx, ids)
                    dome = np.clip(1 - (d / rad) ** 2, 0, 1)
                    height = np.maximum(height, dome)
    shade = r.random(cells * cells)[ids]
    grain = fbm(N, 32, 3, 21)
    h = height * (0.9 + 0.1 * grain)
    light = rgb(0.86, 0.78, 0.62)
    dark = rgb(0.68, 0.58, 0.44)
    color = lerp(dark, light, (0.3 + 0.7 * shade)[..., None]) * (0.92 + 0.16 * grain)[..., None]
    gap = rgb(0.50, 0.42, 0.30)
    color = lerp(gap, color, np.clip(height * 1.6, 0, 1)[..., None])
    save("cobble", color, h, 2.2)
    make_flagstone()


def make_flagstone():
    """Square sandstone flags in a slightly jittered grid: the courtyard and
    keep floors in the renders."""
    r = np.random.default_rng(9)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    cells = 6
    cw = N / cells
    col = np.floor(xs / cw)
    row = np.floor(ys / cw)
    u = (xs % cw) / cw
    v = (ys % cw) / cw
    d = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) * cw
    gap = 4 + 3 * fbm(N, 24, 2, 91)
    height = np.clip((d - gap) / 14, 0, 1)
    height = height * height * (3 - 2 * height)
    ids = (row * 100 + col).astype(int)
    shade = r.random(int(ids.max()) + 1)[ids]
    grain = fbm(N, 20, 3, 92)
    wear = fbm(N, 4, 3, 93)
    light = rgb(0.90, 0.80, 0.62)
    dark = rgb(0.74, 0.62, 0.45)
    color = lerp(dark, light, (0.25 + 0.75 * shade)[..., None]) * (0.92 + 0.16 * grain)[..., None]
    color = lerp(color, rgb(0.70, 0.60, 0.46), np.clip((wear - 0.55) * 3, 0, 1)[..., None] * 0.5)
    joint = rgb(0.60, 0.50, 0.37)
    color = lerp(joint, color, np.clip(height * 1.4, 0, 1)[..., None])
    # Cracks across a few tiles and worn, darker patches where feet pass.
    ridge = fbm(N, 9, 3, 94)
    crack = (np.abs(ridge - 0.5) < 0.004) & (r.random(int(ids.max()) + 1)[ids] > 0.88)
    color = lerp(color, rgb(0.56, 0.47, 0.34), crack[..., None] * 0.7)
    h = height * (0.92 + 0.08 * grain) - 0.15 * crack
    save("flagstone", color, np.clip(h, 0, 1), 1.4)
    # Mossy variant for the elven yard: moss in the joints and on worn tiles.
    moss = np.clip((1 - height) * 1.3 + (fbm(N, 6, 3, 95) - 0.62) * 2.5, 0, 1) * (fbm(N, 3, 2, 96) > 0.5)
    mossy = lerp(color, rgb(0.42, 0.60, 0.30), np.clip(moss * 0.6, 0, 1)[..., None])
    save("flagstone_moss", mossy, np.clip(h, 0, 1), 1.4)


def make_shingle():
    """Scalloped roof shingles in light grey, tinted per team in game: rows
    of overlapping rounded tiles with their own shade."""
    r = np.random.default_rng(12)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    rows = 10
    rh = N / rows
    row = np.floor(ys / rh)
    cols = 8
    cw = N / cols
    offset = (row % 2) * cw * 0.5
    col = np.floor((xs + offset) / cw)
    u = ((xs + offset) % cw) / cw - 0.5
    v = (ys % rh) / rh
    # Each tile is a rounded tongue hanging down over the row below.
    dome = np.clip(1 - (u * 2.0) ** 2, 0, 1)
    tongue = np.where(v < 0.75, 1.0, np.clip((1 - v) / 0.25, 0, 1) * dome)
    lip = np.clip(1 - np.abs(u) * 2.2, 0, 1)
    height = tongue * (0.7 + 0.3 * lip)
    ids = (row * 100 + col).astype(int)
    shade = r.random(int(ids.max()) + 1)[ids]
    grain = fbm(N, 24, 3, 97)
    light = rgb(0.90, 0.90, 0.92)
    dark = rgb(0.62, 0.62, 0.66)
    color = lerp(dark, light, (0.3 + 0.7 * shade)[..., None]) * (0.9 + 0.2 * grain)[..., None]
    color = lerp(rgb(0.40, 0.40, 0.44), color, np.clip(height * 1.5, 0, 1)[..., None])
    save("shingle", color, height, 2.2)


def make_wood():
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    planks = 6
    pw = N / planks
    plank = np.floor(xs / pw)
    u = (xs % pw) / pw
    edge = np.minimum(u, 1 - u) * pw
    gap = np.clip((edge - 4) / 10, 0, 1)
    r = np.random.default_rng(5)
    shade = r.random(planks)[plank.astype(int)]
    offset = r.random(planks)[plank.astype(int)] * N
    # Grain: stretched noise along the plank, with wavy rings.
    grain = fbm(N, 4, 5, 31)
    rings = 0.5 + 0.5 * np.sin((ys + offset) * 0.045 + grain * 9.0 + xs * 0.004)
    streak = fbm(N, 2, 3, 32)
    h = gap * (0.75 + 0.15 * rings + 0.1 * streak)
    light = rgb(0.82, 0.58, 0.36)
    dark = rgb(0.58, 0.38, 0.22)
    color = lerp(dark, light, np.clip(0.35 + 0.5 * shade + 0.25 * rings, 0, 1)[..., None])
    color = lerp(rgb(0.32, 0.20, 0.11), color, gap[..., None])
    # Nail heads near the plank ends and a seam where boards meet.
    seam = np.abs(((ys + offset) % (N / 2)) - N / 4) < 3
    color = lerp(color, rgb(0.34, 0.22, 0.12), (seam * gap * 0.8)[..., None])
    h -= seam * 0.08
    for pi in range(planks):
        for sy in (0.08, 0.42, 0.58, 0.92):
            nx = (pi + 0.5) * pw
            ny = (sy * N / 2 + offset[0, int(nx)]) % N
            d = np.sqrt(((xs - nx + N / 2) % N - N / 2) ** 2 + ((ys - ny + N / 2) % N - N / 2) ** 2)
            nail = np.clip(1 - d / 6, 0, 1)
            color = lerp(color, rgb(0.30, 0.28, 0.26), (nail ** 0.5)[..., None])
            h += nail * 0.08
    # Knots.
    for _ in range(7):
        kx, ky = r.uniform(0, N), r.uniform(0, N)
        d = np.sqrt(((xs - kx + N / 2) % N - N / 2) ** 2 + (((ys - ky + N / 2) % N - N / 2) * 0.6) ** 2)
        knot = np.clip(1 - d / 26, 0, 1)
        color = lerp(color, rgb(0.42, 0.28, 0.16), (knot ** 0.5 * 0.7)[..., None])
        h -= knot * 0.1
    save("wood", color, h, 1.6)


def make_bark():
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    ridges = fbm(N, 6, 4, 41)
    # Long wandering fissures: the sine's phase drifts with low noise so the
    # bark looks hand-painted rather than striped.
    vertical = 0.5 + 0.5 * np.sin(xs * 0.07 + ridges * 16.0 + ys * 0.004)
    vertical = vertical ** 1.6
    cracks = fbm(N, 20, 3, 42)
    knots = fbm(N, 4, 2, 44)
    h = 0.55 * vertical + 0.35 * cracks + 0.1 * knots
    fissure = np.clip((0.22 - vertical) * 5.0, 0, 1)
    light = rgb(0.62, 0.46, 0.30)
    mid = rgb(0.44, 0.31, 0.20)
    dark = rgb(0.22, 0.14, 0.09)
    color = lerp(mid, light, np.clip(h * 1.3 - 0.25, 0, 1)[..., None])
    color = lerp(color, dark, fissure[..., None] * 0.9)
    # Painted ridge highlights where the bark catches the light.
    hl = np.clip((vertical - 0.75) * 4, 0, 1) * (cracks > 0.45)
    color = lerp(color, rgb(0.74, 0.58, 0.40), hl[..., None] * 0.5)
    moss = np.clip((fbm(N, 5, 3, 43) - 0.6) * 4, 0, 1) * (1 - vertical)
    color = lerp(color, rgb(0.40, 0.56, 0.28), np.clip(moss, 0, 1)[..., None] * 0.6)
    save("bark", color, h, 3.0)


def make_grass():
    """A clean meadow: two soft greens in broad, low-contrast patches with a
    fine even nap and nothing that reads as a repeating mark. Flowers,
    tufts and stones are placed by the game, not painted here."""
    macro = fbm(N, 2, 2, 59)
    blotch = fbm(N, 4, 3, 51)
    patches = np.clip((blotch * 0.65 + macro * 0.35) * 1.4 - 0.2, 0, 1)
    nap = fbm(N, 64, 2, 52)
    deep = rgb(0.36, 0.60, 0.24)
    bright = rgb(0.50, 0.74, 0.30)
    color = lerp(deep, bright, patches[..., None])
    color = color * (0.96 + 0.08 * nap)[..., None]
    h = 0.25 * nap + 0.3 * patches
    save("grass", color, np.clip(h, 0, 1), 0.35)


def make_dirt():
    """Packed earth for the road verges: warm, even, a few faint pebbles,
    no ruts or edges (the mapping is triplanar, so nothing directional)."""
    base = fbm(N, 5, 4, 61)
    pebbles = fbm(N, 70, 2, 62) > 0.84
    light = rgb(0.80, 0.68, 0.48)
    dark = rgb(0.68, 0.56, 0.38)
    color = lerp(dark, light, np.clip(base * 1.1, 0, 1)[..., None])
    color = lerp(color, rgb(0.70, 0.66, 0.58), pebbles[..., None] * 0.5)
    h = 0.5 * base + 0.2 * pebbles
    save("dirt", color, np.clip(h, 0, 1), 0.8)


def make_road():
    """A packed-earth road with flat, worn paving stones sunk into it: an
    even cobbled look with no direction to it, so it tiles cleanly under
    the triplanar mapping."""
    base = fbm(N, 5, 4, 81)
    earth_light = rgb(0.80, 0.68, 0.48)
    earth_dark = rgb(0.64, 0.52, 0.36)
    color = lerp(earth_dark, earth_light, np.clip(base * 1.1, 0, 1)[..., None])
    # Flat stones: cells of thresholded noise with soft joints between them.
    cells = fbm(N, 12, 2, 83)
    gy, gx = np.gradient(cells)
    edges = np.abs(gx) + np.abs(gy)
    stone_mask = (edges < 0.0035) & (fbm(N, 4, 2, 84) > 0.38)
    stone_mask = np.array(Image.fromarray((stone_mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))) / 255.0
    stone_tone = lerp(rgb(0.74, 0.68, 0.56), rgb(0.84, 0.78, 0.66), fbm(N, 18, 2, 85)[..., None])
    color = lerp(color, stone_tone, stone_mask[..., None] * 0.85)
    h = 0.4 * base + 0.5 * stone_mask
    save("road", color, np.clip(h, 0, 1), 1.2)


def make_rock():
    """Rough faceted rock for boulders: warm grey with cracks and lichen,
    no block pattern."""
    base = fbm(N, 6, 5, 101)
    cracks = np.abs(fbm(N, 7, 3, 102) - 0.5) < 0.012
    facets = value_noise(N, 10, 103)
    light = rgb(0.80, 0.77, 0.72)
    dark = rgb(0.52, 0.50, 0.46)
    color = lerp(dark, light, np.clip(base * 0.6 + facets * 0.6, 0, 1)[..., None])
    color = lerp(color, rgb(0.38, 0.36, 0.33), cracks[..., None] * 0.8)
    lichen = (fbm(N, 9, 3, 104) > 0.68)
    color = lerp(color, rgb(0.62, 0.70, 0.40), lichen[..., None] * 0.55)
    h = np.clip(0.5 * base + 0.5 * facets - 0.25 * cracks, 0, 1)
    save("rock", color, h, 2.2)


def make_water_noise():
    n = fbm(N // 2, 6, 4, 71)
    Image.fromarray((n * 255).astype(np.uint8)).save(f"{OUT}/water_noise.png")
    print("wrote water_noise")


# --- Marble, carpet, sand, moss and dark planks (the 2026-10-06 overhaul) --

def make_marble():
    """Cream marble for the keep floors: big polished slabs with grey veins."""
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    h, shade = brick_layout(4, 4, 3, 10, 9)
    warp = fbm(N, 3, 4, 91)
    veins = np.abs(np.sin((xs * 0.006 + ys * 0.011) * 3.0 + warp * 14.0))
    veins = np.clip(1 - veins * 7.0, 0, 1) ** 1.5
    veins2 = np.abs(np.sin((xs * 0.013 - ys * 0.004) * 2.0 + fbm(N, 5, 3, 92) * 11.0))
    veins2 = np.clip(1 - veins2 * 10.0, 0, 1) ** 1.5
    cloud = fbm(N, 4, 5, 93)
    base = lerp(rgb(0.9, 0.87, 0.82), rgb(0.97, 0.95, 0.9), (0.3 + 0.7 * cloud)[..., None])
    base = lerp(base, rgb(0.86, 0.84, 0.82), (0.25 * shade)[..., None])
    color = lerp(base, rgb(0.62, 0.6, 0.6), (veins * 0.55 + veins2 * 0.35)[..., None])
    color = lerp(rgb(0.55, 0.52, 0.5), color, h[..., None])
    height = h * (0.92 + 0.08 * cloud) - veins * 0.03
    save("marble", color, np.clip(height, 0, 1), 1.2)


def make_carpet():
    """A woven rug: a wide border, an inner band and a lattice of diamonds.
    Light red so game code can tint it per team."""
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    weave = (np.sin(xs * 0.9) * 0.5 + 0.5) * 0.5 + (np.sin(ys * 0.9) * 0.5 + 0.5) * 0.5
    fuzz = fbm(N, 64, 2, 101)
    # Tiles 1/2 texture across: border 0..0.08, band 0.08..0.14, field inside.
    u = (xs % (N / 2)) / (N / 2)
    v = (ys % (N / 2)) / (N / 2)
    d = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v))
    border = d < 0.07
    band = (d >= 0.07) & (d < 0.11)
    inner = d >= 0.11
    du = np.abs(((u * 6) % 1.0) - 0.5)
    dv = np.abs(((v * 6) % 1.0) - 0.5)
    diamond = ((du + dv) < 0.28) & inner
    small = ((du + dv) < 0.1) & inner
    color = np.where(border[..., None], rgb(0.95, 0.9, 0.78), rgb(0.8, 0.72, 0.68))
    color = np.where(band[..., None], rgb(0.62, 0.56, 0.52), color)
    color = np.where(diamond[..., None], rgb(0.95, 0.88, 0.7), color)
    color = np.where(small[..., None], rgb(0.6, 0.5, 0.45), color)
    color = color * (0.9 + 0.1 * weave + 0.06 * fuzz - 0.06)[..., None]
    height = 0.5 + 0.25 * weave + 0.1 * fuzz + 0.1 * border
    save("carpet", np.clip(color, 0, 1), np.clip(height, 0, 1), 0.9)


def make_sand():
    """Pale river sand with ripples and a few pebbles."""
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    ripple = 0.5 + 0.5 * np.sin(ys * 0.05 + fbm(N, 3, 3, 111) * 6.0)
    grain = fbm(N, 48, 3, 112)
    color = lerp(rgb(0.78, 0.7, 0.54), rgb(0.9, 0.84, 0.68), (0.4 * ripple + 0.6 * grain)[..., None])
    h = 0.4 + 0.3 * ripple + 0.2 * grain
    r = np.random.default_rng(113)
    for _ in range(60):
        px, py = r.uniform(0, N), r.uniform(0, N)
        rad = r.uniform(6, 14)
        d = np.sqrt(((xs - px + N / 2) % N - N / 2) ** 2 + ((ys - py + N / 2) % N - N / 2) ** 2)
        peb = np.clip(1 - d / rad, 0, 1) ** 0.6
        color = lerp(color, rgb(0.62, 0.6, 0.56) * r.uniform(0.8, 1.15), peb[..., None])
        h += peb * 0.25
    save("sand", np.clip(color, 0, 1), np.clip(h, 0, 1), 1.2)


def make_moss():
    """Deep moss and clover for the Wildwood floor."""
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    tuft = fbm(N, 24, 4, 121)
    clumps = fbm(N, 6, 3, 122)
    color = lerp(rgb(0.16, 0.36, 0.18), rgb(0.4, 0.66, 0.3), (0.3 * tuft + 0.7 * clumps)[..., None])
    r = np.random.default_rng(123)
    for _ in range(140):
        px, py = r.uniform(0, N), r.uniform(0, N)
        d = np.sqrt(((xs - px + N / 2) % N - N / 2) ** 2 + ((ys - py + N / 2) % N - N / 2) ** 2)
        leaf = np.clip(1 - d / r.uniform(5, 9), 0, 1)
        color = lerp(color, rgb(0.55, 0.8, 0.4), (leaf ** 0.7 * 0.8)[..., None])
    h = 0.3 + 0.5 * tuft + 0.2 * clumps
    save("moss", np.clip(color, 0, 1), np.clip(h, 0, 1), 1.6)


def make_wood_dark():
    """Weathered dark planks for bridges and piers."""
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    planks = 7
    pw = N / planks
    plank = np.floor(xs / pw)
    u = (xs % pw) / pw
    edge = np.minimum(u, 1 - u) * pw
    gap = np.clip((edge - 5) / 10, 0, 1)
    r = np.random.default_rng(131)
    shade = r.random(planks)[plank.astype(int)]
    offset = r.random(planks)[plank.astype(int)] * N
    grain = fbm(N, 4, 5, 132)
    rings = 0.5 + 0.5 * np.sin((ys + offset) * 0.06 + grain * 10.0 + xs * 0.003)
    h = gap * (0.7 + 0.2 * rings + 0.1 * fbm(N, 2, 3, 133))
    light = rgb(0.5, 0.4, 0.3)
    dark = rgb(0.3, 0.22, 0.15)
    color = lerp(dark, light, np.clip(0.3 + 0.5 * shade + 0.3 * rings, 0, 1)[..., None])
    color = lerp(rgb(0.15, 0.1, 0.06), color, gap[..., None])
    # Silvered, sun-bleached streaks.
    bleach = np.clip(fbm(N, 3, 3, 134) - 0.55, 0, 1) * 2.0
    color = lerp(color, rgb(0.62, 0.6, 0.55), (bleach * gap * 0.6)[..., None])
    save("wood_dark", np.clip(color, 0, 1), np.clip(h, 0, 1), 1.8)


os.makedirs(OUT, exist_ok=True)
make_stone()
make_cobble()
make_wood()
make_bark()
make_grass()
make_shingle()
make_rock()
make_dirt()
make_road()
make_water_noise()
make_marble()
make_carpet()
make_sand()
make_moss()
make_wood_dark()
