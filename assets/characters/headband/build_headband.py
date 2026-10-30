# claude-faisal/headband: team-coloured head pieces fitted to the KayKit Adventurers headgear.
# Own-made geometry (CC0 for the project). Run:
#   blender -b --factory-startup --python build_headband.py -- <out.glb> [preview_dir]
# Every piece is ray-cast onto the rest-pose headgear it rides on, so it wraps the real
# surface instead of floating as a flat sticker:
#   Knight_Crest  a horsehair crest ridge over the helmet top, brow to nape (the match
#                 camera looks down on the helmet top, so this is the Knight's team read)
#   Knight_Band   a band round the helmet above the visor, at its widest girth
#   Bear_Band     a band tied round the Engineer's bear hood above the bear's eyes
#   Bear_Ears     caps over the bear ears (the top of the hood from above)
#   Healer_Band   a cloth headband over the Healer's hair, knotted at the back
#   Mage_Band     a team band over the Mage hat's own band (promotions: their tint washes
#                 the team colour out of the hat)
#   Hood_Band     a band round the Ranger/Rogue hood above the face (promotions, same reason)
# Vertices are in the model's rest space (glTF axes); Godot hangs them on the head bone
# through the bone's inverse rest (OutfitFlair.headband). UVs pick a cell of a 2x1 palette:
# u 0.25 = the team colour, u 0.75 = the trim (darker team colour, or gold from rank 2).
import bpy, bmesh, sys, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "C:/Temp/headband.glb"
PREVIEW = argv[1] if len(argv) > 1 else ""
CHARS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEAM, TRIM = 0.25, 0.75

bpy.ops.wm.read_factory_settings(use_empty=True)


def load(model, part):
    """The rest-pose world-space BVH of `part` in the KayKit `model`."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(CHARS, f"{model}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    rig = next(o for o in new if o.type == 'ARMATURE')
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    ob = next(o for o in new if o.name.startswith(part))
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(ob.matrix_world)
    bvh = BVHTree.FromBMesh(bm)
    return new, bvh


def hit(bvh, origin, target):
    d = (Vector(target) - Vector(origin))
    loc, nor, fi, dist = bvh.ray_cast(Vector(origin), d.normalized(), d.length + 1.0)
    return loc


def smooth(vals, k=1, passes=2, wrap=True):
    n = len(vals)
    for _ in range(passes):
        out = []
        for i in range(n):
            acc, w = 0.0, 0
            for j in range(-k, k + 1):
                ii = i + j
                if wrap:
                    ii %= n
                elif ii < 0 or ii >= n:
                    continue
                acc += vals[ii]
                w += 1
            out.append(acc / w)
        vals = out
    return vals


class Builder:
    def __init__(self):
        self.verts, self.faces, self.uvs = [], [], []

    def v(self, p):
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def f(self, idx, u):
        self.faces.append(idx)
        self.uvs.append(u)

    def object(self, name):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.verts], [], self.faces)
        uv = me.uv_layers.new(name="UVMap")
        for poly, u in zip(me.polygons, self.uvs):
            for li in poly.loop_indices:
                uv.data[li].uv = (u, 0.5)
        me.validate()
        for poly in me.polygons:
            poly.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def band(b, bvh, z_lo, z_hi, centre, off=0.025, depth=0.035, n=36, bulge=0.012, max_r=None, rim=0.18):
    """A band round the headgear between heights z_lo and z_hi (Blender Z), following the surface.
    Rings of 6 verts: inner bottom, outer bottom, outer lower rim, outer upper rim, outer top, inner top.
    The outer rims carry the trim colour, the middle and the top face the team colour."""
    cx, cy = centre
    zs = [z_lo, (z_lo + z_hi) / 2, z_hi]
    radii = []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.sin(a), -math.cos(a), 0))   # i=0 is the front (-Y)
        r = 0.0
        for z in zs:
            p = hit(bvh, (cx + d.x * 3, cy + d.y * 3, z), (cx, cy, z))
            if p is not None:
                r = max(r, (Vector((p.x - cx, p.y - cy, 0))).length)
        radii.append(r)
    good = [r for r in radii if r > 0]
    radii = [r if r > 0 else min(good) for r in radii]
    if max_r:
        radii = [min(r, max_r) for r in radii]
    radii = smooth(radii, 1, 2)
    h = z_hi - z_lo
    rings = []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.sin(a), -math.cos(a), 0))
        r = radii[i] + off
        c = Vector((cx, cy, 0))
        ring = [
            c + d * (r - depth) + Vector((0, 0, z_lo)),
            c + d * r + Vector((0, 0, z_lo)),
            c + d * (r + bulge) + Vector((0, 0, z_lo + h * rim)),
            c + d * (r + bulge) + Vector((0, 0, z_hi - h * rim)),
            c + d * r + Vector((0, 0, z_hi)),
            c + d * (r - depth) + Vector((0, 0, z_hi)),
        ]
        rings.append([b.v(p) for p in ring])
    cols = [TRIM, TRIM, TEAM, TRIM, TEAM, TRIM]   # the top face stays team (seen from above)
    for i in range(n):
        A, B = rings[i], rings[(i + 1) % n]
        for k in range(6):
            k2 = (k + 1) % 6
            b.f([A[k], B[k], B[k2], A[k2]], cols[k])
    return radii


def crest(b, bvh, centre, th0, th1, h, w_lo, w_hi, n=26, sink=0.03):
    """A crest ridge in the YZ plane (x = 0) over the headgear from angle th0 (front, negative)
    to th1 (down the back), measured from straight up round `centre` (y, z)."""
    cy, cz = centre
    rs = []
    ths = [th0 + (th1 - th0) * i / (n - 1) for i in range(n)]
    for th in ths:
        d = Vector((0, math.sin(th), math.cos(th)))
        r = 0.0
        for x in (-w_lo, 0.0, w_lo):   # under the whole base, so spikes never poke through
            p = hit(bvh, (x, cy + d.y * 3, cz + d.z * 3), (x, cy, cz))
            if p is not None:
                r = max(r, Vector((0, p.y - cy, p.z - cz)).length)
        rs.append(r)
    good = [r for r in rs if r > 0]
    rs = [r if r > 0 else min(good) for r in rs]
    rs = smooth(rs, 2, 3, wrap=False)
    rings = []
    for i, th in enumerate(ths):
        d = Vector((0, math.sin(th), math.cos(th)))
        t = i / (n - 1)
        # Full height over the crown, tapering to the brow and the nape.
        taper = min(1.0, t / 0.18, (1.0 - t) / 0.3)
        taper = 0.25 + 0.75 * math.sin(max(0.0, taper) * math.pi / 2)
        hh = h * taper
        wt = w_hi * (0.6 + 0.4 * taper)
        base = Vector((0, cy, cz)) + d * (rs[i] - sink)
        top = Vector((0, cy, cz)) + d * (rs[i] + hh)
        mid = Vector((0, cy, cz)) + d * (rs[i] + hh * 0.35)
        ring = [
            base + Vector((-w_lo, 0, 0)),
            mid + Vector((-wt * 0.85, 0, 0)),
            top + Vector((-wt * 0.6, 0, 0)) - d * 0.02,
            top + d * 0.025,
            top + Vector((wt * 0.6, 0, 0)) - d * 0.02,
            mid + Vector((wt * 0.85, 0, 0)),
            base + Vector((w_lo, 0, 0)),
        ]
        rings.append([b.v(p) for p in ring])
    cols = [TRIM, TEAM, TEAM, TEAM, TEAM, TRIM]
    for i in range(n - 1):
        A, B = rings[i], rings[i + 1]
        for k in range(6):
            b.f([A[k], A[k + 1], B[k + 1], B[k]], cols[k])
    # End caps.
    for R, flip in ((rings[0], True), (rings[-1], False)):
        idx = list(R) if not flip else list(reversed(R))
        b.f(idx, TEAM)


def ear_caps(b, bvh, centres, rad, h, n=10):
    """Domed caps over the bear ears: rays straight down on a disc round each ear top."""
    for (ex, ey, ez) in centres:
        ring_r = []
        top = hit(bvh, (ex, ey, 4.0), (ex, ey, 0.0))
        tz = top.z if top else ez
        rows = []
        for j, f in enumerate((1.0, 0.7, 0.35)):
            row = []
            for i in range(n):
                a = 2 * math.pi * i / n
                x, y = ex + math.cos(a) * rad * f, ey + math.sin(a) * rad * 0.8 * f
                p = hit(bvh, (x, y, 4.0), (x, y, 0.0))
                z = (p.z if p and p.z > tz - 0.3 else tz - 0.12 * f) + h * (1.0 - 0.4 * f)
                row.append(b.v((x, y, z if j else z - h * 0.9)))
            rows.append(row)
        apex = b.v((ex, ey, tz + h))
        for j in range(len(rows) - 1):
            A, B = rows[j], rows[j + 1]
            for i in range(n):
                i2 = (i + 1) % n
                b.f([A[i], A[i2], B[i2], B[i]], TEAM if j else TRIM)
        for i in range(n):
            b.f([rows[-1][i], rows[-1][(i + 1) % n], apex], TEAM)


def knot(b, at, size):
    """A small faceted knot (an octahedron) with two tails hanging down and back."""
    x, y, z = at
    s = size
    pts = [b.v((x + s, y, z)), b.v((x - s, y, z)), b.v((x, y + s * 0.8, z)), b.v((x, y - s * 0.4, z)),
           b.v((x, y, z + s * 0.8)), b.v((x, y, z - s * 0.8))]
    px, nx, py, ny, pz, nz = pts
    for tri in ((px, py, pz), (py, nx, pz), (nx, ny, pz), (ny, px, pz), (py, px, nz), (nx, py, nz), (ny, nx, nz), (px, ny, nz)):
        b.f(list(tri), TEAM)
    for side, ln, sw in ((-1, 0.36, 0.25), (1, 0.30, -0.15)):
        w, t = 0.075, 0.025
        top = Vector((x + side * 0.05, y + 0.02, z - 0.02))
        bot = top + Vector((side * sw * ln, 0.13, -ln))
        q = [b.v(top + Vector((-w, -t, 0))), b.v(top + Vector((w, -t, 0))), b.v(bot + Vector((w * 1.2, -t, 0))), b.v(bot + Vector((-w * 1.2, -t, 0))),
             b.v(top + Vector((-w, t, 0))), b.v(top + Vector((w, t, 0))), b.v(bot + Vector((w * 1.2, t, 0))), b.v(bot + Vector((-w * 1.2, t, 0)))]
        for f in ((0, 1, 2, 3), (5, 4, 7, 6), (4, 0, 3, 7), (1, 5, 6, 2), (3, 2, 6, 7)):
            b.f([q[i] for i in f], TEAM if f != (3, 2, 6, 7) else TRIM)


built = []
# --- Knight -----------------------------------------------------------------------
kn, kb = load("Knight", "Knight_Helmet")
b = Builder()
crest(b, kb, centre=(-0.04, 1.86), th0=math.radians(-48), th1=math.radians(112), h=0.17, w_lo=0.075, w_hi=0.16)
built.append(b.object("Knight_Crest"))
b = Builder()
band(b, kb, 1.86, 1.97, centre=(0.0, -0.05), off=0.018, depth=0.04, bulge=0.014)
built.append(b.object("Knight_Band"))
# --- Engineer (bear hood) -----------------------------------------------------------
bn, bb = load("Barbarian", "Barbarian_Hat")
b = Builder()
band(b, bb, 2.02, 2.12, centre=(0.0, -0.08), off=0.016, depth=0.04, bulge=0.014)
built.append(b.object("Bear_Band"))
b = Builder()
ear_caps(b, bb, [(-0.42, 0.06, 2.3), (0.42, 0.06, 2.3)], rad=0.17, h=0.045)
built.append(b.object("Bear_Ears"))
# --- Healer (Mage body, bare head) ---------------------------------------------------
mn, mb = load("Mage", "Mage_Head")
b = Builder()
radii = band(b, mb, 1.885, 1.985, centre=(0.0, 0.0), off=0.012, depth=0.035, bulge=0.012, rim=0.25)
back_r = radii[len(radii) // 2] + 0.03
knot(b, (0.0, back_r, 1.935), 0.075)
built.append(b.object("Healer_Band"))

# --- Promotions: Mage hat and the hood -----------------------------------------------
_, hb = load("Mage", "Mage_Hat")
b = Builder()
band(b, hb, 2.1, 2.27, centre=(0.0, 0.02), off=0.014, depth=0.04, bulge=0.012, rim=0.2)
built.append(b.object("Mage_Band"))
rn, rb = load("Rogue_Hooded", "Rogue_Head_Hooded")
b = Builder()
band(b, rb, 1.95, 2.04, centre=(0.0, 0.0), off=0.014, depth=0.04, bulge=0.012)
built.append(b.object("Hood_Band"))

# Keep only our pieces and export them (glTF axes: Y up, the model faces +Z).
for o in list(bpy.data.objects):
    o.select_set(o in built)
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format='GLB', export_yup=True,
                          export_apply=False, export_materials='NONE', export_animations=False)
for o in built:
    print("PIECE", o.name, "verts", len(o.data.vertices), "tris", sum(len(p.vertices) - 2 for p in o.data.polygons))

if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = 'BLENDER_WORKBENCH'
    except TypeError as e:
        print(e)
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'OBJECT'
    sc.render.resolution_x = sc.render.resolution_y = 420
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.color = (0.25, 0.45, 0.9, 1) if o in built else (0.6, 0.6, 0.62, 1)
            nm = o.name
            if o not in built and not any(k in nm for k in ("Head", "Hat", "Helmet", "Body")):
                o.hide_render = True
    cam = bpy.data.cameras.new("c")
    cam.type = 'ORTHO'
    cam.ortho_scale = 1.9
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    groups = {"knight": kn, "bear": bn, "healer": mn, "mage": mn, "hood": rn}
    shown = {o: not o.hide_render for o in bpy.data.objects}
    views = {"front": ((0, -6, 1.8), (math.pi / 2, 0, 0)), "side": ((6, 0, 1.8), (math.pi / 2, 0, math.pi / 2)),
             "back": ((0, 6, 1.8), (math.pi / 2, 0, math.pi)), "match": ((0, 3.6, 5.6), (math.radians(40), 0, math.pi)),
             "top": ((0, 0, 7), (0, 0, 0))}
    for key, objs in groups.items():
        mine = set(objs) | {o for o in built if o.name.lower().startswith(key)}
        if key == "healer":
            mine = {o for o in mine if "Hat" not in o.name}
        for o in bpy.data.objects:
            if o.type == 'MESH':
                o.hide_render = not (shown[o] and o in mine)
        for vn, (loc, rot) in views.items():
            co.location = loc
            co.rotation_euler = rot
            sc.render.filepath = os.path.join(PREVIEW, f"{key}_{vn}.png")
            bpy.ops.render.render(write_still=True)
