"""Forest kit trees as modelled meshes (claude-faisal/crowns-polish round 5,
2026-11-01; reviewers: four rounds of procedural tiers still read as coarse
outlined clusters). Builds Pick D's pines and Pick A's broadleaf trees in
Blender from many small, noise-displaced, overlapping needle / leaf clumps
on a visible trunk, decimated to the kit's per-tree triangle budget, and
writes each as a flat float32 vertex stream that tools/import_kit_trees.gd
turns into assets/models/kit/*.res:

    per triangle corner: x y z  nx ny nz  shade hue kind   (Godot axes, y up)
    shade: 0 (deep under / inside) .. 1 (sunlit top)
    hue:   0..1 per clump, for a slight per-clump hue jitter
    kind:  0 foliage, 1 bark

Colours are not baked: forest_kit.gd maps shade/hue through each map's
palette (day, night, winter snow, twilight dusk), so every variant comes
from the same mesh. Run:
    blender -b --factory-startup -P tools/blender/kit_trees.py -- <out_dir>
"""
import math
import os
import random
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(OUT, exist_ok=True)

# Kit shapes (forest_kit.gd _make_pine / _make_broad) and triangle budgets
# (the procedural meshes these replace: pine 6.3k / 4.9k / 7.5k, broad 1.4k / 1.2k / 1.9k).
PINES = {0: dict(tiers=5, base_r=1.7, top=5.4, foot=0.72, budget=6200),
         1: dict(tiers=4, base_r=1.3, top=3.4, foot=0.5, budget=4800),
         2: dict(tiers=6, base_r=1.8, top=6.0, foot=0.78, budget=7400)}
BROADS = {0: dict(trunk_h=1.7, crown_r=1.45, budget=1900),
          1: dict(trunk_h=1.9, crown_r=1.25, budget=1700),
          2: dict(trunk_h=1.55, crown_r=1.6, budget=2100)}


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.shade = self.bm.verts.layers.float.new("shade")
        self.hue = self.bm.verts.layers.float.new("hue")
        self.kind = self.bm.verts.layers.float.new("kind")

    def _tag(self, verts, shade_fn, hue, kind):
        for v in verts:
            v[self.shade] = shade_fn(v)
            v[self.hue] = hue
            v[self.kind] = kind

    def clump(self, c, r, squash, seed, hue, lit, droop=None, subdiv=2):
        """A needle / leaf clump: an icosphere squashed, noise-displaced
        (lumpy, irregular) and drooped; shaded by its normal (lit top, dark
        under) times `lit` (how exposed it sits in the crown)."""
        droop = droop if droop is not None else Vector((0, 0, 0))
        ret = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0)
        verts = ret["verts"]
        off = Vector((seed * 1.37, seed * 2.11, seed * 0.53))
        for v in verts:
            d = v.co.normalized()
            n = noise.noise(d * 1.9 + off)
            n2 = noise.noise(d * 4.3 + off * 1.7)
            k = 1.0 + 0.3 * n + 0.14 * n2
            p = Vector((d.x * r * k, d.y * r * k, d.z * r * k * squash))
            p += droop * max(0.0, -d.z * 0.5 + 0.5) * r
            v.co = c + p
        cc = c.copy()

        def sh(v):
            d = (v.co - cc).normalized()
            up = d.z * 0.5 + 0.5
            return max(0.0, min(1.0, (0.12 + 0.88 * up ** 1.3) * lit))
        self._tag(verts, sh, hue, 0.0)

    def tube(self, a, b, ra, rb, sides, shade_a, shade_b):
        """A bark tube from a to b."""
        axis = b - a
        L = axis.length
        ret = bmesh.ops.create_cone(self.bm, cap_ends=False, segments=sides, radius1=ra, radius2=rb, depth=L)
        rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=ret["verts"])
        for v in ret["verts"]:
            t = (v.co - a).dot(axis) / (L * L)
            v[self.shade] = shade_a + (shade_b - shade_a) * max(0.0, min(1.0, t))
            v[self.hue] = 0.5
            v[self.kind] = 1.0

    def cone(self, c, r, h, sides, shade_lo, shade_hi, hue):
        """A tier's body cone (round 6: wide and shaded from its rim up to
        a sunlit top, so each tier reads as a clear cone step)."""
        ret = bmesh.ops.create_cone(self.bm, cap_ends=False, segments=sides, radius1=r, radius2=0.0, depth=h)
        bmesh.ops.translate(self.bm, vec=c + Vector((0, 0, h / 2)), verts=ret["verts"])
        cz = c.z
        self._tag(ret["verts"], lambda v: shade_lo + (shade_hi - shade_lo) * max(0.0, min(1.0, (v.co.z - cz) / h)), hue, 0.0)


def pine(shape):
    P = PINES[shape]
    rnd = random.Random(1000 + shape)
    b = Builder()
    tiers, base_r, top, foot = P["tiers"], P["base_r"], P["top"], P["foot"]
    sc = base_r / 1.7
    b.tube(Vector((0, 0, -0.1)), Vector((0, 0, foot + (top - foot) * 0.4)), 0.25 * sc, 0.1, 7, 0.08, 0.25)
    for k in range(3):
        a = math.tau * k / 3 + rnd.random() * 0.7
        b.tube(Vector((math.cos(a) * 0.36 * sc, math.sin(a) * 0.36 * sc, -0.05)), Vector((0, 0, 0.45)), 0.06, 0.13, 5, 0.2, 0.3)
    step = (top - foot) / (tiers + 0.3)
    seed = shape * 1000
    for i in range(tiers):
        f = i / max(tiers - 1, 1)
        rr = base_r * (1.0 - f * 0.62)
        rim = foot + step * i
        h = step * 1.5
        off = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)) * rr * (0.0 if i == 0 else 0.06)
        b.cone(off + Vector((0, 0, rim + h * 0.02)), rr * 0.86, h * 0.92, 14, 0.45, 0.95, 0.5)
        # Rim ring: small clumps drooping out past the filler.
        n_rim = max(8, round(rr * 11.0))
        spin = rnd.random() * math.tau
        for k in range(n_rim):
            a = spin + math.tau * (k + rnd.uniform(-0.25, 0.25)) / n_rim
            d = Vector((math.cos(a), math.sin(a), 0))
            cr = rr * rnd.uniform(0.17, 0.23)
            c = off + d * rr * rnd.uniform(0.86, 0.94) + Vector((0, 0, rim + h * rnd.uniform(0.06, 0.12)))
            seed += 1
            b.clump(c, cr, 0.55, seed, rnd.random(), 0.9 + 0.1 * f, droop=d * 0.2 + Vector((0, 0, -0.15)))
        # Shoulder ring higher in: the tier's sunlit top.
        n_mid = max(3, round(rr * 3.0))
        for k in range(n_mid):
            a = spin + math.tau * (k + 0.5 + rnd.uniform(-0.2, 0.2)) / n_mid
            d = Vector((math.cos(a), math.sin(a), 0))
            cr = rr * rnd.uniform(0.17, 0.22)
            c = off + d * rr * rnd.uniform(0.5, 0.58) + Vector((0, 0, rim + h * rnd.uniform(0.34, 0.42)))
            seed += 1
            b.clump(c, cr, 0.7, seed, rnd.random(), 1.0)
    seed += 1
    b.clump(Vector((0, 0, top - step * 0.25)), base_r * 0.2, 0.9, seed, rnd.random(), 1.05)
    return b, P["budget"]


def broad(shape):
    P = BROADS[shape]
    rnd = random.Random(2000 + shape)
    b = Builder()
    th, cr = P["trunk_h"], P["crown_r"]
    cy = th + cr * 0.7
    b.tube(Vector((0, 0, -0.1)), Vector((0, 0, th + 0.4)), 0.22, 0.12, 7, 0.1, 0.35)
    for k in range(3):
        a = math.tau * k / 3 + rnd.random() * 0.6
        b.tube(Vector((math.cos(a) * 0.36, math.sin(a) * 0.36, -0.05)), Vector((0, 0, 0.45)), 0.07, 0.14, 5, 0.2, 0.3)
    for k in range(3):
        a = math.tau * k / 3 + rnd.random() * 0.8
        b.tube(Vector((0, 0, th * 0.8)), Vector((math.cos(a) * cr * 0.28, math.sin(a) * cr * 0.28, cy - cr * 0.25)), 0.08, 0.04, 5, 0.3, 0.45)
    seed = 5000 + shape * 100
    seed += 1
    b.clump(Vector((0, 0, cy)), cr * 0.72, 0.85, seed, 0.5, 0.7)   # the core (round 6: not near black)
    n = 30
    for k in range(n):
        u = (k + 0.5) / n
        z = max(-0.45, 1.0 - u * 1.25)     # a dome, from the top to below the equator
        ring = math.sqrt(max(0.0, 1.0 - z * z))
        a = k * 2.399963 + rnd.random() * 0.3   # golden-angle spiral
        d = Vector((math.cos(a) * ring, math.sin(a) * ring, z * 0.8))
        c = Vector((0, 0, cy)) + d * cr * rnd.uniform(0.66, 0.8)
        seed += 1
        b.clump(c, cr * rnd.uniform(0.22, 0.3), 0.78, seed, rnd.random(), 0.75 + 0.3 * max(0.0, z))
    return b, P["budget"]


def write(name, b, budget):
    me = bpy.data.meshes.new(name)
    b.bm.to_mesh(me)
    b.bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.calc_loop_triangles()
    tris = len(me.loop_triangles)
    me2 = me
    if tris > budget:
        m = ob.modifiers.new("dec", "DECIMATE")
        m.ratio = budget / tris
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    me2.calc_loop_triangles()
    sh = me2.attributes["shade"].data
    hu = me2.attributes["hue"].data
    kd = me2.attributes["kind"].data
    out = bytearray()
    nv = 0
    for t in me2.loop_triangles:
        for vi in t.vertices:
            v = me2.vertices[vi]
            # Blender z-up -> Godot y-up.
            out += struct.pack("<9f", v.co.x, v.co.z, -v.co.y, v.normal.x, v.normal.z, -v.normal.y,
                               sh[vi].value, hu[vi].value, kd[vi].value)
            nv += 1
    with open(os.path.join(OUT, name + ".bin"), "wb") as f:
        f.write(out)
    print("KIT", name, "tris", tris, "->", nv // 3)


for s in PINES:
    b, bud = pine(s)
    write("pine%d" % s, b, bud)
for s in BROADS:
    b, bud = broad(s)
    write("broad%d" % s, b, bud)
