"""Castle textures for the 2026-10-31 castle pass (claude-faisal/crowns-castle),
to Faisal's picks Spawn D / Live battle A: large warm-cream courtyard flags
and chunky castle wall blocks, each slab or block its own shade, with a deep
hand-cut bevel, a painted lit top arris and shaded foot (the game camera is
fixed, so the bevel light is painted in as the picks do), and a darker,
wider warm joint than the 10-14 style set, so the stone still reads as laid
blocks under the warm key light instead of washing out to a flat cream.

Writes assets/textures/style/castle_flags*, castle_blocks* (_color, _normal).
Only the match world reads them (scripts/visual/style_profile.gd TEX).
Run from the project root:
    python tools/make_castle_textures.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_style_textures as mst  # noqa: E402

N = mst.N
rgb = mst.rgb
lerp = mst.lerp
fbm = mst.fbm


def _layout(G, seed, big=0.7, rows_only=False):
    """An irregular bond on a G x G grid: squares, 2x1 / 1x2 doubles and 2x2
    slabs (rows_only: courses of 1-3 cell long blocks, as a wall's bond)."""
    r = np.random.default_rng(seed)
    owner = -np.ones((G, G), dtype=int)
    rects = []
    for cy in range(G):
        for cx in range(G):
            if owner[cy, cx] >= 0:
                continue
            if rows_only:
                w = 1
                while w < 3 and cx + w < G and owner[cy, cx + w] < 0 and r.random() < 0.55:
                    w += 1
                h = 1
            else:
                # Mostly squares and long-way doubles (the picks' bond), few tall ones.
                opts = [((1, 1), 0.45)]
                if cx + 1 < G and owner[cy, cx + 1] < 0:
                    opts.append(((2, 1), 0.35))
                if cy + 1 < G:
                    opts.append(((1, 2), 0.12))
                    if cx + 1 < G and owner[cy, cx + 1] < 0 and owner[cy + 1, cx + 1] < 0:
                        opts.append(((2, 2), 0.08))
                wsum = sum(o[1] for o in opts)
                pick = r.random() * wsum
                w, h = opts[-1][0]
                for o, wt in opts:
                    if pick < wt:
                        w, h = o
                        break
                    pick -= wt
            for yy in range(cy, cy + h):
                for xx in range(cx, cx + w):
                    owner[yy, xx] = len(rects)
            rects.append((cx, cy, cx + w, cy + h))
    return owner, rects


def _slabs(owner, rects, gx_n, gy_n, joint, bevel, wobble, seed):
    """Per-pixel slab id, the bevel profile t (0 joint .. 1 face) and the
    position inside the slab (cu, cv in -0.5..0.5)."""
    cw = N / gx_n
    ch = N / gy_n
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float64)
    wx = xs + (fbm(N, 16, 3, seed) - 0.5) * wobble
    wy = ys + (fbm(N, 16, 3, seed + 1) - 0.5) * wobble
    px = wx % N
    py = wy % N
    gx = np.clip(px // cw, 0, gx_n - 1).astype(int)
    gy = np.clip(py // ch, 0, gy_n - 1).astype(int)
    ids = owner[gy, gx]
    R = np.array(rects, dtype=np.float64)
    x0, y0, x1, y1 = R[ids, 0] * cw, R[ids, 1] * ch, R[ids, 2] * cw, R[ids, 3] * ch
    du = np.minimum(px - x0, x1 - px)
    dv = np.minimum(py - y0, y1 - py)
    d = -np.log(np.exp(-du / 8.0) + np.exp(-dv / 8.0)) * 8.0
    t = np.clip((d - joint) / bevel, 0, 1)
    cu = (px - x0) / np.maximum(x1 - x0, 1) - 0.5
    cv = (py - y0) / np.maximum(y1 - y0, 1) - 0.5
    # Which edge is nearest: +1 near the top edge, -1 near the bottom, for the painted arris light.
    top_edge = (py - y0) < (y1 - py)
    left_edge = (px - x0) < (x1 - px)
    vert_near = dv <= du
    return ids, t, cu, cv, top_edge, left_edge, vert_near


def _paint(ids, t, cu, cv, top_edge, left_edge, vert_near, n, palette, joint_col, seed, chips=0.7):
    r = np.random.default_rng(seed)
    face = np.sin(t * np.pi / 2) ** 0.75
    pick = r.integers(0, len(palette), n)[ids]
    pal = np.array(palette)
    base = pal[pick]
    shade = (r.random(n) - 0.5)[ids]
    base = base * (1.0 + 0.10 * shade)[..., None]
    # Broad mottling and a speckle inside every face.
    mott = fbm(N, 6, 3, seed + 2)
    base = base * (0.94 + 0.12 * mott)[..., None]
    speck = np.clip((fbm(N, 150, 2, seed + 3) - 0.6) * 4, 0, 1)
    base = base * (1.0 - 0.05 * speck)[..., None]
    # Painted bevel light: the upper and left arrises lit, the lower and right in shade.
    band = np.clip(1.0 - t, 0, 1) * (t > 0.0)
    lit = np.where(vert_near, np.where(top_edge, 1.0, -1.0), np.where(left_edge, 0.55, -0.55))
    base = base * (1.0 + band * lit * 0.22)[..., None]
    # Worn chips on the arrises.
    chip = np.clip((fbm(N, 44, 2, seed + 4) - chips) * 6.0, 0, 1) * (t < 0.8) * (t > 0.0)
    base = lerp(base, base * 0.78, (chip * 0.8)[..., None])
    # A soft warm contact shade where the face meets the joint.
    base = lerp(base, base * 0.8, (np.clip(1 - t * 2.5, 0, 1) * (t > 0))[..., None])
    jt = np.clip(t * 6.0, 0, 1)
    color = lerp(np.broadcast_to(joint_col, base.shape) * (0.9 + 0.2 * mott)[..., None], base, jt[..., None])
    height = np.clip(face * (0.8 + 0.12 * (r.random(n)[ids] - 0.5)) + fbm(N, 12, 4, seed + 5) * 0.06 * face - chip * 0.25, 0, 1)
    return color, height, chip


def make_castle_flags():
    """Courtyard flags: ~1.25 m units at the yards' 0.16 UV (5 per 6.25 m
    tile), mixed squares and doubles, warm cream to peach to pale tan."""
    G = 5
    owner, rects = _layout(G, 411, big=0.6)
    ids, t, cu, cv, te, le, vn = _slabs(owner, rects, G, G, joint=7.0, bevel=26.0, wobble=7.0, seed=412)
    palette = [rgb(0.93, 0.83, 0.65), rgb(0.95, 0.86, 0.69), rgb(0.90, 0.78, 0.60), rgb(0.94, 0.80, 0.63),
               rgb(0.88, 0.80, 0.66), rgb(0.96, 0.88, 0.72), rgb(0.86, 0.75, 0.58)]
    color, height, _chip = _paint(ids, t, cu, cv, te, le, vn, len(rects), palette, rgb(0.48, 0.37, 0.26), 413)
    # A whisper of moss and grit in the joints.
    grit = np.clip(1 - t * 3, 0, 1) * np.clip((fbm(N, 10, 2, 414) - 0.55) * 4, 0, 1)
    color = lerp(color, rgb(0.40, 0.48, 0.24), (grit * 0.4)[..., None])
    mst.save("castle_flags", color, height, 1.0)
    # The Humans' and the snowy keep floors: the same flags in cool grey.
    grey = [rgb(0.74, 0.74, 0.76), rgb(0.70, 0.71, 0.74), rgb(0.78, 0.77, 0.76), rgb(0.66, 0.68, 0.72), rgb(0.80, 0.79, 0.78)]
    gcol, gh, _c = _paint(ids, t, cu, cv, te, le, vn, len(rects), grey, rgb(0.36, 0.35, 0.36), 415)
    mst.save("castle_flags_grey", gcol, gh, 1.0)


def make_castle_blocks():
    """Castle wall blocks: courses of 1-3 unit blocks (~0.55 m tall, 0.6-1.8 m
    long at the walls' 0.3 UV: 6 courses and 6 units per 3.33 m tile), big
    soft bevels, warm cream; and the Humans' grey."""
    G = 6
    owner, rects = _layout(G, 421, rows_only=True)
    ids, t, cu, cv, te, le, vn = _slabs(owner, rects, G, G, joint=6.0, bevel=24.0, wobble=5.0, seed=422)
    palette = [rgb(0.92, 0.83, 0.66), rgb(0.88, 0.78, 0.60), rgb(0.95, 0.87, 0.71), rgb(0.86, 0.77, 0.62),
               rgb(0.93, 0.80, 0.62), rgb(0.90, 0.84, 0.72)]
    color, height, _chip = _paint(ids, t, cu, cv, te, le, vn, len(rects), palette, rgb(0.45, 0.35, 0.25), 423, chips=0.68)
    mst.save("castle_blocks", color, height, 1.0)
    grey = [rgb(0.70, 0.71, 0.74), rgb(0.64, 0.66, 0.70), rgb(0.76, 0.76, 0.77), rgb(0.60, 0.63, 0.68), rgb(0.72, 0.70, 0.67)]
    gcol, gh, _c = _paint(ids, t, cu, cv, te, le, vn, len(rects), grey, rgb(0.32, 0.32, 0.34), 424, chips=0.68)
    mst.save("castle_blocks_grey", gcol, gh, 1.0)


def make_castle_face():
    """The face of one modelled block (coping, merlons, courtyard wall
    blocks, tower trim): the blocks' cream stone with no joints (the model's
    own bevel and gaps are the joints), broad mottling, speckle and a few
    worn chips; and the Humans' grey."""
    for name, deep, light, seed in (("castle_face", rgb(0.80, 0.69, 0.52), rgb(0.92, 0.82, 0.65), 431),
                                    ("castle_face_grey", rgb(0.62, 0.64, 0.68), rgb(0.78, 0.78, 0.79), 432)):
        mott = fbm(N, 5, 4, seed)
        color = lerp(deep, light, np.clip(mott * 1.3 - 0.1, 0, 1)[..., None])
        speck = np.clip((fbm(N, 150, 2, seed + 1) - 0.6) * 4, 0, 1)
        chip = np.clip((fbm(N, 30, 2, seed + 2) - 0.7) * 6.0, 0, 1)
        color = color * (1.0 - 0.06 * speck - 0.16 * chip)[..., None]
        height = np.clip(0.7 + fbm(N, 12, 4, seed + 3) * 0.2 - chip * 0.3, 0, 1)
        mst.save(name, color, height, 0.6)


if __name__ == "__main__":
    os.makedirs(mst.OUT, exist_ok=True)
    for fn in sys.argv[1:] or ["make_castle_flags", "make_castle_blocks", "make_castle_face"]:
        globals()[fn]()
