"""World textures for the 2026-10-14 visual overhaul (Faisal's style guide:
"a cohesive, vibrant, stylized 3D fantasy world").

Writes assets/textures/style/<name>_color + _normal. The match world picks
these up through game.gd's style table (STYLE_TEX); the menus, the title
diorama and the hall keep the original assets/textures/ files, which this
script never touches. Every surface follows one grammar:

  * one detail scale: cobbles ~0.8 m, wall blocks ~0.5 x 0.8 m, floor slabs
    ~1 m, planks ~0.25 m, bark grooves ~0.25 m (with the game's UV scales);
  * soft, rounded bevels and mid-value joints (no near-black ink lines: the
    ink outline pass draws the silhouettes);
  * matte painted fills, each piece its own close shade, gentle top light;
  * normal maps about half as strong as before.

The path maps keep the exact channel layout PATH_SHADER reads (see
make_stepping_stones). Run from the project root:
    python3 tools/make_style_textures.py            # everything
    python3 tools/make_style_textures.py make_paths  # one generator
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT = "assets/textures/style"
N = 1024


def lerp(a, b, t):
    return a + (b - a) * t


def rgb(r, g, b):
    return np.array([r, g, b])


def value_noise(size, cells, seed):
    """Tileable value noise (as tools/make_textures.py)."""
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


def normal_map(height, strength):
    """OpenGL-style normal map (Godot's convention) from a 0..1 height field."""
    h = height * strength
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    nz = np.ones_like(h) * (2.0 / N) * 40.0
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    n = np.stack([-dx / length, dy / length, nz / length], axis=-1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, color, height, strength):
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(f"{OUT}/{name}_color.jpg", quality=92)
    Image.fromarray(normal_map(np.clip(height, 0, 1), strength)).save(f"{OUT}/{name}_normal.jpg", quality=92)
    print("wrote", name)


def voronoi(size, cells, seed, jitter=0.9):
    """Tileable Voronoi: F1, F2 (cell units) and the nearest cell's id."""
    r = np.random.default_rng(seed)
    off = 0.5 + (r.random((cells, cells, 2)) - 0.5) * jitter
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) * (cells / size)
    cx = np.floor(xs).astype(int)
    cy = np.floor(ys).astype(int)
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    ids = np.zeros((size, size), dtype=int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nx = cx + dx
            ny = cy + dy
            wx = nx % cells
            wy = ny % cells
            px = nx + off[wy, wx, 0]
            py = ny + off[wy, wx, 1]
            d = np.hypot(xs - px, ys - py)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ids = np.where(closer, wy * cells + wx, ids)
            f1 = np.where(closer, d, f1)
    return f1, f2, ids


def wrap_filter(mask, filt):
    pad = N // 8
    big = np.pad(mask, pad, mode="wrap")
    img = Image.fromarray((np.clip(big, 0, 1) * 255).astype(np.uint8)).filter(filt)
    return np.asarray(img).astype(np.float64)[pad:-pad, pad:-pad] / 255.0


def blocks(rows, cols, joint, bevel, seed, stagger=True):
    """Staggered blocks: a rounded-bevel height (1 on the face, 0 in the
    joint), each block's own shade, and v (0 top .. 1 bottom of its course)."""
    r = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    row_h = N / rows
    col_w = N / cols
    row = np.floor(ys / row_h)
    offset = (row % 2) * col_w * 0.5 if stagger else 0.0
    col = np.floor((xs + offset) / col_w)
    u = ((xs + offset) % col_w) / col_w
    v = (ys % row_h) / row_h
    du = np.minimum(u, 1 - u) * col_w
    dv = np.minimum(v, 1 - v) * row_h
    # Rounded corners: distance into the block measured as a soft minimum.
    d = -np.log(np.exp(-du / 6.0) + np.exp(-dv / 6.0)) * 6.0
    height = np.clip((d - joint) / bevel, 0, 1)
    height = np.sin(height * np.pi / 2) ** 0.8
    ids = (row * 1000 + col % cols).astype(int)
    shade = r.random(int(ids.max()) + 1)[ids]
    tint = r.random(int(ids.max()) + 1)[ids]
    return height, shade, tint, v, u


def painted_block_color(height, shade, tint, v, deep, light, warm, cool, joint, seed):
    """Matte painted block faces: a close range of shades, a gentle light
    from above (lighter top edge, slightly deeper foot), soft broad mottling,
    and a mid-value joint."""
    color = lerp(deep, light, (0.45 + 0.55 * shade)[..., None])
    color = lerp(color, warm, (np.clip(tint - 0.6, 0, 1) * 0.8)[..., None])
    color = lerp(color, cool, (np.clip(0.4 - tint, 0, 1) * 0.8)[..., None])
    color = color * (1.04 - 0.09 * v)[..., None]
    mottle = fbm(N, 8, 3, seed)
    color = color * (0.97 + 0.06 * mottle)[..., None]
    rim = np.clip(1.0 - height, 0, 1) * (height > 0.02)
    color = lerp(color, color * 0.86, rim[..., None] * 0.6)
    return lerp(joint, color, np.clip(height * 1.4, 0, 1)[..., None])


# --- Paths ----------------------------------------------------------------------

def make_stepping_stones(name, cells, seed, drop):
    """The style guide's forest path: small rounded tan flagstones set in
    packed earth. Same three files and channel layout as the original
    (tools/make_textures.py make_stepping_stones): {name}_color.png (opaque,
    stones and joints), {name}_normal.jpg and {name}_stones.png, whose R and
    G are the offset from each pixel to its stone's centre (UV units, 0.5 =
    none), B that stone's random value and A 1 on a stone, 0.25 in a joint.
    Half again as many stones a side as before (cells 6): about 0.8 m
    across at the road's 0.2 UV scale, the size of the guide's path stones
    next to a fighter."""
    k = cells / 4.0   # blur radii were tuned for 4 cells a tile
    f1, f2, ids = voronoi(N, cells, seed)
    r = np.random.default_rng(seed + 1)
    keep = (r.random(cells * cells) >= drop)[ids]
    inner = ((f2 - f1) > 0.12) & keep
    soft = wrap_filter(inner.astype(np.float64), ImageFilter.GaussianBlur(12 / k))
    stone = soft > 0.5
    core = wrap_filter(stone.astype(np.float64), ImageFilter.MinFilter(3)) > 0.5
    dome = wrap_filter(core.astype(np.float64), ImageFilter.GaussianBlur(14 / k))
    crown = np.clip((f2 - f1) / 0.4, 0, 1) ** 0.6
    sh = int(round(9 / k))
    lit = wrap_filter(np.roll(np.roll(core, sh, axis=0), sh, axis=1).astype(np.float64) * core,
                      ImageFilter.GaussianBlur(6 / k))
    shade = r.random(cells * cells)[ids]
    hue = r.random(cells * cells)[ids]
    sand = rgb(0.88, 0.76, 0.56)
    tan = rgb(0.78, 0.64, 0.46)
    grey = rgb(0.74, 0.69, 0.60)
    base = lerp(tan, sand, shade[..., None])
    base = lerp(base, grey, (np.clip(hue - 0.7, 0, 1) * 2.0)[..., None])
    color = base * (0.84 + 0.08 * dome + 0.05 * crown + 0.1 * lit)[..., None]
    rim = rgb(0.52, 0.42, 0.30)
    color = np.where(core[..., None], color, rim)
    # Packed earth in the joints (the guide's path reads as a path, not stones
    # floating in the lawn), with moss creeping in here and there; never black.
    mottle = fbm(N, 10, 2, seed + 7)
    turf = lerp(rgb(0.34, 0.46, 0.18), rgb(0.42, 0.55, 0.22), mottle[..., None])
    earth = rgb(0.50, 0.38, 0.24)
    joint = lerp(earth, turf, np.clip((mottle - 0.55) * 2.5, 0, 0.7)[..., None])
    color = np.where(stone[..., None], color, joint)
    height = 0.6 * wrap_filter(core.astype(np.float64), ImageFilter.GaussianBlur(4 / k)) + 0.4 * dome
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8), "RGB").save(f"{OUT}/{name}_color.png")
    Image.fromarray(normal_map(height, 0.7)).save(f"{OUT}/{name}_normal.jpg", quality=92)
    r2 = np.random.default_rng(seed)
    off = 0.5 + (r2.random((cells, cells, 2)) - 0.5) * 0.9   # as voronoi() draws them
    wy, wx = ids // cells, ids % cells
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64) * (cells / N)
    dx = (wx + off[wy, wx, 0] - xs + cells / 2) % cells - cells / 2
    dy = (wy + off[wy, wx, 1] - ys + cells / 2) % cells - cells / 2
    rnd = r.random(cells * cells)[ids]
    data = np.stack([np.clip(0.5 + dx / cells * 2, 0, 1), np.clip(0.5 + dy / cells * 2, 0, 1),
                     rnd, np.where(stone, 1.0, 0.25)], axis=-1)
    Image.fromarray((data * 255 + 0.5).astype(np.uint8), "RGBA").save(f"{OUT}/{name}_stones.png")
    print("wrote", name)


def make_paths():
    make_stepping_stones("path", 6, 401, 0.0)
    make_stepping_stones("path_loose", 6, 402, 0.3)


def make_rosette():
    """The round paved courts (shrine plaza, dais tiers, door aprons): the
    same rings of flags as the original decal (tools/make_textures.py
    make_rosette, same layout and alpha), in the guide's warm grey-tan stone
    with soft joints and a muted kerb, instead of yellow flags and red brick."""
    r = np.random.default_rng(23)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    cx = (xs - N / 2 + 0.5) / (N / 2)
    cy = (ys - N / 2 + 0.5) / (N / 2)
    rad = np.hypot(cx, cy)
    ang = (np.arctan2(cy, cx) + np.pi) / (2 * np.pi)
    kerb_in = 0.9
    ring_w = kerb_in / 6.5
    ring = np.floor(rad / ring_w)
    rv = (rad / ring_w) - ring
    segs = np.maximum(1, np.round(2 * np.pi * (ring + 0.5) * ring_w / 0.2)).astype(int)
    segs = np.where(ring == 0, 1, segs)
    off = (ring % 2) * 0.5
    seg_pos = (ang * segs + off) % segs
    sid = np.floor(seg_pos)
    su = seg_pos - sid
    px = N / 2 * ring_w
    arc = 2 * np.pi * np.maximum(rad, 1e-3) / segs * (N / 2)
    d = np.minimum(np.minimum(rv, 1 - rv) * px, np.minimum(su, 1 - su) * arc)
    d = np.where(ring == 0, (ring_w - rad) * N / 2, d)
    flag = np.clip((d - 3.0) / 6.0, 0, 1)
    flag = np.sin(flag * np.pi / 2)
    ids = (ring * 997 + sid).astype(int)
    shade = r.random(int(ids.max()) + 1)[ids]
    light = rgb(0.92, 0.80, 0.60)
    dark = rgb(0.80, 0.67, 0.49)
    color = lerp(dark, light, (0.3 + 0.7 * shade)[..., None])
    alt = (ring % 2 == 1)
    color = lerp(color, rgb(0.84, 0.72, 0.54), alt[..., None] * 0.35)
    color = color * (0.95 + 0.1 * fbm(N, 8, 3, 241))[..., None]
    joint = rgb(0.50, 0.39, 0.27)
    color = lerp(joint, color, flag[..., None])
    kerb = (rad >= kerb_in) & (rad < 0.995)
    kseg = (ang * 64) % 1.0
    kd = np.minimum(np.minimum(rad - kerb_in, 0.995 - rad) * N / 2, np.minimum(kseg, 1 - kseg) * 2 * np.pi * rad / 64 * N / 2)
    brick = lerp(rgb(0.58, 0.48, 0.38), rgb(0.70, 0.58, 0.44), r.random(64)[(ang * 64).astype(int) % 64][..., None])
    brick = lerp(joint, brick, np.clip((kd - 3.0) / 4.0, 0, 1)[..., None])
    color = np.where(kerb[..., None], brick, color)
    alpha = np.clip((0.995 - rad) * N / 2, 0, 1)
    rgba = np.concatenate([np.clip(color, 0, 1), alpha[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(f"{OUT}/rosette_color.png")
    Image.fromarray(normal_map(np.where(kerb, 1.0, flag) * alpha, 0.6)).save(f"{OUT}/rosette_normal.jpg", quality=92)
    print("wrote rosette")


# --- Masonry --------------------------------------------------------------------

def make_stone():
    """Elven cream sandstone wall blocks (the guide's warm stone)."""
    h, shade, tint, v, _u = blocks(5, 3, joint=5, bevel=16, seed=151)
    color = painted_block_color(h, shade, tint, v, deep=rgb(0.80, 0.72, 0.57), light=rgb(0.93, 0.87, 0.73),
                                warm=rgb(0.92, 0.80, 0.62), cool=rgb(0.82, 0.80, 0.72), joint=rgb(0.56, 0.48, 0.37), seed=152)
    save("stone", color, h, 0.7)


def make_greystone():
    """Human castle blocks: the guide's chunky grey stone, a spread of warm
    and cool greys, soft bevels, a mid-grey joint."""
    h, shade, tint, v, _u = blocks(5, 3, joint=5, bevel=16, seed=161)
    color = painted_block_color(h, shade, tint, v, deep=rgb(0.50, 0.52, 0.55), light=rgb(0.74, 0.75, 0.77),
                                warm=rgb(0.70, 0.67, 0.62), cool=rgb(0.60, 0.64, 0.72), joint=rgb(0.34, 0.34, 0.36), seed=162)
    save("greystone", color, h, 0.7)


def make_flagstone():
    """Floor slabs, three to a tile as before (1.3 m at the floors' 0.25 UV scale), with
    soft bevels; plus the mossy (Elf) and grey (Human) variants."""
    h, shade, tint, v, _u = blocks(3, 3, joint=4, bevel=12, seed=171, stagger=False)
    v = v * 0.4   # a floor: barely any top-to-bottom light
    color = painted_block_color(h, shade, tint, v, deep=rgb(0.84, 0.77, 0.62), light=rgb(0.95, 0.90, 0.78),
                                warm=rgb(0.93, 0.82, 0.64), cool=rgb(0.86, 0.84, 0.78), joint=rgb(0.62, 0.55, 0.43), seed=172)
    save("flagstone", color, h, 0.6)
    moss = np.clip((1 - h) * 1.3 + (fbm(N, 6, 3, 173) - 0.62) * 2.5, 0, 1) * np.clip((fbm(N, 3, 2, 174) - 0.45) * 8, 0, 1)
    mossy = lerp(color * rgb(0.98, 1.0, 0.94), rgb(0.40, 0.56, 0.24), np.clip(moss * 0.55, 0, 1)[..., None])
    save("flagstone_moss", mossy, h, 0.6)
    grey = painted_block_color(h, shade, tint, v, deep=rgb(0.58, 0.58, 0.60), light=rgb(0.76, 0.76, 0.77),
                               warm=rgb(0.74, 0.70, 0.64), cool=rgb(0.68, 0.69, 0.72), joint=rgb(0.46, 0.45, 0.45), seed=175)
    save("flagstone_grey", grey, h, 0.6)


def make_rock():
    """Boulders and river kerbs: the guide's soft grey rock, broad facets,
    a little moss low down; no lime blotches."""
    base = fbm(N, 5, 4, 181)
    facets = value_noise(N, 8, 182)
    light = rgb(0.74, 0.73, 0.71)
    dark = rgb(0.48, 0.48, 0.48)
    color = lerp(dark, light, np.clip(base * 0.55 + facets * 0.6, 0, 1)[..., None])
    color = lerp(color, color * rgb(1.04, 1.0, 0.95), (fbm(N, 3, 2, 183))[..., None] * 0.6)
    moss = np.clip((fbm(N, 7, 3, 185) - 0.66) * 4, 0, 1)
    color = lerp(color, rgb(0.42, 0.52, 0.28), moss[..., None] * 0.45)
    h = np.clip(0.5 * base + 0.5 * facets, 0, 1)
    save("rock", color, h, 1.0)


def make_cobble():
    """River-bank cobbles (the pebbly strip): small rounded stones at the
    same size as the path's (12 a tile at UV 0.6, ~0.14 m: a pebble beach),
    soft greys and tans in a turf joint."""
    f1, f2, ids = voronoi(N, 12, 191)
    r = np.random.default_rng(192)
    inner = (f2 - f1) > 0.14
    soft = wrap_filter(inner.astype(np.float64), ImageFilter.GaussianBlur(4))
    stone = soft > 0.5
    dome = wrap_filter(stone.astype(np.float64), ImageFilter.GaussianBlur(5))
    shade = r.random(144)[ids]
    base = lerp(rgb(0.66, 0.62, 0.56), rgb(0.84, 0.79, 0.70), shade[..., None])
    color = base * (0.86 + 0.14 * dome)[..., None]
    joint = lerp(rgb(0.46, 0.36, 0.24), rgb(0.38, 0.42, 0.22), np.clip(fbm(N, 8, 2, 193) - 0.3, 0, 0.6)[..., None])
    color = np.where(stone[..., None], color, joint)
    save("cobble", color, 0.5 * stone + 0.5 * dome, 0.8)


# --- Timber and bark ---------------------------------------------------------------

def _planks(planks, light, dark, gap_col, seed, grain_amt):
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    pw = N / planks
    plank = np.floor(xs / pw).astype(int)
    u = (xs % pw) / pw
    edge = np.minimum(u, 1 - u) * pw
    gap = np.clip((edge - 4) / 14, 0, 1)
    gap = np.sin(gap * np.pi / 2)
    r = np.random.default_rng(seed)
    shade = r.random(planks)[plank]
    offset = r.random(planks)[plank] * N
    grain = fbm(N, 4, 4, seed + 1)
    rings = 0.5 + 0.5 * np.sin((ys + offset) * 0.03 + grain * 7.0 + xs * 0.003)
    color = lerp(dark, light, np.clip(0.3 + 0.5 * shade + grain_amt * (rings - 0.5), 0, 1)[..., None])
    # A butt joint per plank, softly darkened.
    seam = np.clip(1 - np.abs(((ys + offset) % (N / 2)) - N / 4) / 4, 0, 1)
    color = lerp(color, color * 0.72, (seam * gap * 0.7)[..., None])
    color = lerp(gap_col, color, gap[..., None])
    h = gap * (0.85 + 0.1 * rings) - seam * 0.06
    return color, h


def make_wood():
    """Timber (posts, rails, crates, decks): the guide's warm red-brown."""
    color, h = _planks(5, rgb(0.66, 0.44, 0.27), rgb(0.47, 0.30, 0.18), rgb(0.27, 0.17, 0.10), 201, 0.35)
    save("wood", color, h, 0.7)


def make_wood_dark():
    """Dark planks (bridge decks, floors): deep warm brown, a little worn."""
    color, h = _planks(5, rgb(0.48, 0.33, 0.21), rgb(0.33, 0.22, 0.14), rgb(0.17, 0.11, 0.07), 211, 0.35)
    wear = np.clip(fbm(N, 3, 3, 213) - 0.55, 0, 1) * 1.6
    color = lerp(color, rgb(0.56, 0.45, 0.34), (wear * h * 0.4)[..., None])
    save("wood_dark", color, h, 0.7)


def make_bark():
    """Trunks: dark warm brown with broad soft grooves (no busy cracks or
    green streaks), lighter ridges catching the light."""
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    warp = fbm(N, 4, 3, 221)
    groove = 0.5 + 0.5 * np.sin(xs / N * 2 * np.pi * 8 + (warp - 0.5) * 5.0 + ys * 0.002)
    groove = groove ** 1.3
    fine = fbm(N, 16, 2, 222)
    h = 0.75 * groove + 0.25 * fine
    color = lerp(rgb(0.24, 0.16, 0.10), rgb(0.46, 0.32, 0.20), np.clip(h * 1.2 - 0.1, 0, 1)[..., None])
    color = lerp(color, rgb(0.56, 0.41, 0.27), np.clip((groove - 0.8) * 4, 0, 1)[..., None] * 0.35)
    save("bark", color, h, 0.9)


def make_grass():
    """The meadow: rich mid green, broad calm swathes, faint large cells
    (no lime): flowers, paths and fighters read on top of it."""
    f1, f2, ids = voronoi(N, 4, 231)
    r = np.random.default_rng(232)
    shade = r.random(16)[ids]
    broad = fbm(N, 2, 3, 233)
    fine = fbm(N, 24, 2, 234)
    base = rgb(0.27, 0.52, 0.16)
    light = rgb(0.38, 0.63, 0.20)
    warm = rgb(0.46, 0.62, 0.20)
    color = lerp(base, light, (shade * 0.35 + np.clip((broad - 0.45) * 1.6, 0, 1) * 0.5)[..., None])
    color = lerp(color, warm, np.clip((fbm(N, 3, 2, 235) - 0.6) * 3, 0, 1)[..., None] * 0.35)
    color = color * (0.96 + 0.08 * fine)[..., None]
    seam = np.clip(1 - (f2 - f1) / 0.04, 0, 1)
    color = lerp(color, color * 0.9, seam[..., None] * 0.25)
    h = 0.5 + 0.5 * fine
    save("grass", color, h, 0.12)


def make_pavers():
    """The courtyard floors (picks Spawn D / Battle A, 2026-10-30): cream
    flags of mixed sizes laid in an irregular ashlar bond (~1 m units at the
    yards' 0.16 UV scale: squares, 2 m doubles and big 2 m slabs), each
    slab its own close shade, with a rounded, slightly hand-cut bevel, worn
    chips on the arrises, a faint crack here and there and a mid-brown joint,
    so the floor reads as laid stone under the game camera, not a flat tile."""
    r = np.random.default_rng(311)
    G = 6
    owner = -np.ones((G, G), dtype=int)
    rects = []
    for cy in range(G):
        for cx in range(G):
            if owner[cy, cx] >= 0:
                continue
            opts = [(1, 1)]
            if cx + 1 < G and owner[cy, cx + 1] < 0:
                opts.append((2, 1))
            if cy + 1 < G:
                opts.append((1, 2))
                if cx + 1 < G and owner[cy, cx + 1] < 0 and owner[cy + 1, cx + 1] < 0:
                    opts += [(2, 2)]
            w, h = opts[r.integers(len(opts))] if r.random() < 0.72 else (1, 1)
            for yy in range(cy, cy + h):
                for xx in range(cx, cx + w):
                    owner[yy, xx] = len(rects)
            rects.append((cx, cy, cx + w, cy + h))
    cell = N / G
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    # Hand-cut edges: the joint wanders a few pixels.
    wob = (fbm(N, 16, 3, 312) - 0.5) * 9.0
    wx = xs + wob
    wy = ys + (fbm(N, 16, 3, 313) - 0.5) * 9.0
    gx = np.clip((wx % N) // cell, 0, G - 1).astype(int)
    gy = np.clip((wy % N) // cell, 0, G - 1).astype(int)
    ids = owner[gy, gx]
    R = np.array(rects, dtype=np.float64) * cell
    x0, y0, x1, y1 = R[ids, 0], R[ids, 1], R[ids, 2], R[ids, 3]
    px = wx % N
    py = wy % N
    du = np.minimum(px - x0, x1 - px)
    dv = np.minimum(py - y0, y1 - py)
    d = -np.log(np.exp(-du / 7.0) + np.exp(-dv / 7.0)) * 7.0
    joint, bevel = 3.5, 22.0
    t = np.clip((d - joint) / bevel, 0, 1)
    face = np.sin(t * np.pi / 2) ** 0.7
    n = len(rects)
    shade = r.random(n)[ids]
    tint = r.random(n)[ids]
    # Each slab sits a touch proud or sunk and tilts a little: relief between slabs.
    lift = (r.random(n) * 0.16)[ids]
    tilt_a = (r.random(n) - 0.5)[ids] * 0.10
    tilt_b = (r.random(n) - 0.5)[ids] * 0.10
    cu = (px - x0) / np.maximum(x1 - x0, 1) - 0.5
    cv = (py - y0) / np.maximum(y1 - y0, 1) - 0.5
    surf = fbm(N, 12, 4, 314)
    # Worn chips on the arrises and the odd crack.
    chip = np.clip((fbm(N, 40, 2, 315) - 0.62) * 6.0, 0, 1) * (t < 0.75) * (t > 0.0)
    cf1, cf2, _cid = voronoi(N, 5, 316, 1.0)
    crack = np.clip(1 - (cf2 - cf1) / 0.018, 0, 1) * np.clip((fbm(N, 4, 2, 317) - 0.68) * 6, 0, 1) * (t > 0.9)
    height = face * (0.76 + lift + tilt_a * cu + tilt_b * cv) + surf * 0.07 * face - chip * 0.25 - crack * 0.12
    height = np.clip(height, 0, 1)
    v = np.clip(0.5 + cv, 0, 1) * 0.35
    color = painted_block_color(face, shade, tint, v, deep=rgb(0.80, 0.70, 0.52), light=rgb(0.95, 0.88, 0.71),
                                warm=rgb(0.94, 0.80, 0.58), cool=rgb(0.85, 0.83, 0.75), joint=rgb(0.60, 0.50, 0.37), seed=318)
    # A lit upper arris and a deeper shade in the groove (painted contact light).
    color = color * (1.0 + 0.07 * np.clip(1 - np.abs(t - 0.55) * 4, 0, 1) * (cv < 0))[..., None]
    color = lerp(color, color * 0.8, (chip * 0.7)[..., None])
    color = lerp(color, rgb(0.55, 0.46, 0.34), (crack * 0.55)[..., None])
    speck = np.clip((fbm(N, 160, 2, 319) - 0.62) * 4, 0, 1) * 0.035
    color = color * (1.0 - speck)[..., None]
    # Grit and a whisper of moss in the joints.
    grit = np.clip(1 - t * 3, 0, 1) * np.clip((fbm(N, 10, 2, 320) - 0.55) * 4, 0, 1)
    color = lerp(color, rgb(0.42, 0.50, 0.26), (grit * 0.45)[..., None])
    save("pavers", color, height, 1.0)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    jobs = sys.argv[1:] or ["make_paths", "make_rosette", "make_stone", "make_greystone", "make_flagstone", "make_rock", "make_cobble",
                            "make_wood", "make_wood_dark", "make_bark", "make_grass", "make_pavers"]
    for fn in jobs:
        globals()[fn]()
