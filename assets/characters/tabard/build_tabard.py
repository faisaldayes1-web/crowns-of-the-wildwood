# claude-faisal/tabard: builds a team tabard skinned to the KayKit Adventurers rig.
# Own-made geometry (CC0 for the project). Run:
#   blender -b --factory-startup --python build_tabard.py -- <Model> <out.glb> [preview_dir]
#   Knight -> tabard_knight.glb, Mage -> tabard_healer.glb (Healers wear the Mage body).
# The tabard is ray-cast onto the model's body in rest pose: a front strip with a
# shoulder yoke and straps, a back panel, and flared skirt panels hanging under the
# belt (the belt, buckle and the chest rosette stay visible). Upper parts copy the
# body's own spine/chest/hips weights; the skirts blend hips into the thighs.
# Two meshes: "Tabard" (front + back) and "Tabard_Front" (no back: worn under a cape).
import bpy, bmesh, sys, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
MODEL = argv[0] if argv else "Knight"
OUT = argv[1] if len(argv) > 1 else f"C:/Temp/tabard_{MODEL.lower()}.glb"
PREVIEW = argv[2] if len(argv) > 2 else ""

# Per body: belt band, skirt hem height, panel widths. Measured from the rest pose renders.
P = {
    "Knight": dict(belt_top=0.665, belt_bot=0.495, strip=0.125, back=0.24, yoke=0.30,
                   skirt_front=(0.26, 0.40, 0.15), skirt_back=(0.28, 0.42, 0.14), flare=0.10, off=0.024,
                   arms=("Knight_ArmLeft", "Knight_ArmRight"), shoulder=(0.19, 0.40, 1.107), leg=1.0),
    "Mage": dict(belt_top=0.775, belt_bot=0.605, strip=0.12, back=0.24, yoke=0.30,
                 skirt_front=(0.25, 0.34, 0.40), skirt_back=(0.27, 0.36, 0.40), flare=0.05, off=0.024,
                 arms=("Mage_ArmLeft", "Mage_ArmRight"), shoulder=(0.19, 0.40, 1.107), leg=0.3),
}[MODEL]

bpy.ops.wm.read_factory_settings(use_empty=True)
# the KayKit model next to this folder (assets/characters/<Model>.glb)
CHARS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.import_scene.gltf(filepath=os.path.join(CHARS, f"{MODEL}.glb"))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = bpy.data.objects[f"{MODEL}_Body"]
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
ev = body.evaluated_get(dg)
me = ev.to_mesh()
bm = bmesh.new()
bm.from_mesh(me)
bm.transform(body.matrix_world)
bm.verts.ensure_lookup_table()
bm.faces.ensure_lookup_table()
bvh = BVHTree.FromBMesh(bm)
gidx = {g.index: g.name for g in body.vertex_groups}
vweights = []
for v in body.data.vertices:
    d = {}
    for g in v.groups:
        n = gidx[g.group]
        if n in ("hips", "spine", "chest"):
            d[n] = g.weight
    vweights.append(d)

OFF = P["off"]


def hit(origin, direction):
    loc, nor, fi, dist = bvh.ray_cast(Vector(origin), Vector(direction).normalized(), 10.0)
    if loc is None:
        return None
    return loc - Vector(direction).normalized() * OFF


def weights_at(p):
    loc, nor, fi, dist = bvh.find_nearest(p)
    f = bm.faces[fi]
    acc = {}
    tot = 0.0
    for v in f.verts:
        w = 1.0 / max((v.co - loc).length, 1e-4)
        tot += w
        for n, x in vweights[v.index].items():
            acc[n] = acc.get(n, 0.0) + x * w
    s = sum(acc.values()) or 1.0
    return {n: x / s for n, x in acc.items()}


# ---- upper shell: columns across x, stations front (z up) -> over the shoulder -> back (z down)
XS = [-P["yoke"], -0.24, -0.18, -P["strip"], -0.06, 0.0, 0.06, P["strip"], 0.18, 0.24, P["yoke"]]
ZF = [P["belt_top"]] + [z for z in (0.73, 0.80, 0.87, 0.94, 1.01, 1.07) if z > P["belt_top"] + 0.03] + [1.12]
PHI = [math.radians(a) for a in (28, 48, 68, 90, 112, 132, 152)]
ZB = list(reversed(ZF))
STATIONS = [("f", z) for z in ZF] + [("t", a) for a in PHI] + [("b", z) for z in ZB]


def station_point(x, st):
    kind, val = st
    if kind == "f":
        return hit((x, -2.0, val), (0, 1, 0))
    if kind == "b":
        return hit((x, 2.0, val), (0, -1, 0))
    c = Vector((x, 0.0, 0.98))
    d = Vector((0, -math.cos(val), math.sin(val)))
    return hit(c + d * 2.0, -d)


def included(x, si):
    kind, val = STATIONS[si]
    ax = abs(x) + 1e-6
    if kind == "f":
        return ax <= P["strip"] + 1e-4 or (val >= 1.12 and ax <= P["yoke"] + 1e-4)
    if kind == "b":
        return ax <= P["back"] + 1e-4 or (val >= 1.07 and ax <= P["yoke"] + 1e-4)
    # over the shoulders: straps only, an open neck in the middle
    ti = si - len(ZF)
    if ax >= P["strip"] - 1e-4:
        return True
    return ti in (0, len(PHI) - 1)


def build_upper(bmo, back: bool):
    grid = {}
    for ci, x in enumerate(XS):
        for si, st in enumerate(STATIONS):
            if STATIONS[si][0] == "b" and not back:
                continue
            if not included(x, si):
                continue
            p = station_point(x, st)
            if p is not None:
                grid[(ci, si)] = bmo.verts.new(p)
    faces = []
    for ci in range(len(XS) - 1):
        for si in range(len(STATIONS) - 1):
            ks = [(ci, si), (ci + 1, si), (ci + 1, si + 1), (ci, si + 1)]
            if all(k in grid for k in ks):
                # without the back, stop the straps at the shoulder top
                if not back and STATIONS[si + 1][0] == "t" and si + 1 - len(ZF) > 3:
                    continue
                faces.append(bmo.faces.new([grid[k] for k in ks]))
    return faces


def build_skirt(bmo, front: bool):
    w_top, w_bot, z_bot = P["skirt_front"] if front else P["skirt_back"]
    sy = -1.0 if front else 1.0
    z_top = P["belt_bot"]
    cols = 9
    rows = [0.0, 0.34, 0.68, 0.86, 1.0]
    vs = {}
    for c in range(cols):
        u = c / (cols - 1) * 2.0 - 1.0
        xt = u * w_top
        top = hit((xt, sy * 2.0, z_top), (0, -sy, 0))
        if top is None:
            top = Vector((xt, sy * 0.3, z_top))
        for r, t in enumerate(rows):
            x = u * (w_top + (w_bot - w_top) * t)
            # hangs straight down, swinging out; a little bulge mid-way; the
            # sides wrap back toward the body
            out = P["flare"] * t + 0.02 * math.sin(t * math.pi)
            wrap = 0.16 * (u ** 4) * (0.4 + t)
            z = z_top + (z_bot - z_top) * t
            y = top.y + sy * (out - wrap)
            # never inside a flared robe: ride on its surface if it is further out
            h = hit((x, sy * 2.0, z), (0, -sy, 0))
            if h is not None and sy * h.y > sy * y:
                y = h.y
            p = Vector((x, y, z))
            vs[(c, r)] = bmo.verts.new(p)
    cloth, hem = [], []
    for c in range(cols - 1):
        for r in range(len(rows) - 1):
            ks = [(c, r), (c + 1, r), (c + 1, r + 1), (c, r + 1)]
            f = bmo.faces.new([vs[k] for k in ks])
            (hem if r == len(rows) - 2 else cloth).append(f)
    return vs, rows, cols, cloth, hem


ARM_BVH = None
if "arms" in P:
    abm = bmesh.new()
    for an in P["arms"]:
        ao = bpy.data.objects[an]
        am = ao.evaluated_get(dg).to_mesh()
        tmp = bmesh.new()
        tmp.from_mesh(am)
        tmp.transform(ao.matrix_world)
        mm = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mm)
        abm.from_mesh(mm)
        tmp.free()
    ARM_BVH = BVHTree.FromBMesh(abm)
CAP_VERTS = []


def build_caps(bmo):
    """Cloth shoulder caps over the top of each upper arm: they stick out past the
    big helmet, so the team colour shows from the match camera."""
    x0, x1, zc = P["shoulder"]
    angs = [math.radians(a) for a in (-115, -85, -55, -25, 0, 25, 55, 85, 115)]
    xs = [x0, x0 + (x1 - x0) * 0.35, x0 + (x1 - x0) * 0.7, x1 - 0.02, x1]
    hem, cloth = [], []
    for side in (1.0, -1.0):
        vs = {}
        for i, xx in enumerate(xs):
            for j, a in enumerate(angs):
                d = Vector((0.0, -math.sin(a), math.cos(a)))
                c = Vector((side * xx, 0.0, zc))
                loc, nor, fi, dist = ARM_BVH.ray_cast(c + d * 1.0, -d, 2.0)
                if loc is None:
                    loc = c + d * 0.12
                # puff out: more at the outer rim, flaring down over the arm
                puff = 0.03 + 0.03 * (i / (len(xs) - 1))
                p = loc + d * puff
                if i == len(xs) - 1:
                    p = p + d * 0.02 + Vector((0, 0, -0.015))
                v = bmo.verts.new(p)
                vs[(i, j)] = v
                CAP_VERTS.append((v, side))
        for i in range(len(xs) - 1):
            for j in range(len(angs) - 1):
                ks = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)] if side > 0 else [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                f = bmo.faces.new([vs[k] for k in ks])
                (hem if i == len(xs) - 2 else cloth).append(f)
    return hem


def make(name: str, back: bool):
    bmo = bmesh.new()
    CAP_VERTS.clear()
    cap_hem = build_caps(bmo) if ARM_BVH else []
    upper = build_upper(bmo, back)
    skirts = [build_skirt(bmo, True)]
    if back:
        skirts.append(build_skirt(bmo, False))
    bmesh.ops.remove_doubles(bmo, verts=bmo.verts, dist=1e-5)
    bmo.normal_update()
    # outward normals: faces should point away from the body axis
    for f in bmo.faces:
        c = f.calc_center_median()
        radial = Vector((c.x, c.y, 0.0))
        if abs(c.x) > P.get("shoulder", (9,))[0] - 0.005 and c.z > 0.95 and "shoulder" in P:
            radial = Vector((0.0, c.y, c.z - P["shoulder"][2]))
        if c.z > 1.15:
            radial = Vector((c.x * 0.3, c.y, (c.z - 0.98)))
        if f.normal.dot(radial) < 0:
            f.normal_flip()
    m = bpy.data.meshes.new(name)
    bmo.to_mesh(m)
    ob = bpy.data.objects.new(name, m)
    bpy.context.scene.collection.objects.link(ob)
    # UVs: cloth at u=0.25, hem at u=0.75 of the runtime palette
    hem_centers = [f.calc_center_median().copy() for f in cap_hem]
    cap_pts = [(v.co.copy(), side) for v, side in CAP_VERTS]
    for sk in skirts:
        for f in sk[4]:
            hem_centers.append(f.calc_center_median().copy())
    uv = m.uv_layers.new(name="UVMap")
    for poly in m.polygons:
        is_hem = any((poly.center - h).length < 1e-4 for h in hem_centers)
        for li in poly.loop_indices:
            uv.data[li].uv = (0.75 if is_hem else 0.25, 0.5)
    for poly in m.polygons:
        poly.use_smooth = False
    # weights
    groups = {n: ob.vertex_groups.new(name=n) for n in ("hips", "spine", "chest", "upperleg.l", "upperleg.r", "upperarm.l", "upperarm.r")}
    cap_set = {}
    for co, side in cap_pts:
        cap_set[(round(co.x, 5), round(co.y, 5), round(co.z, 5))] = side
    zt = P["belt_bot"]
    for v in m.vertices:
        p = v.co
        key = (round(p.x, 5), round(p.y, 5), round(p.z, 5))
        if key in cap_set:
            # the inner edge eases into the chest so the seam doesn't tear
            inner = abs(p.x) < P["shoulder"][0] + 0.03
            arm_n = "upperarm.l" if cap_set[key] > 0 else "upperarm.r"
            w = {arm_n: 0.6, "chest": 0.4} if inner else {arm_n: 1.0}
        elif p.z <= zt + 1e-3 and p.z < 0.6:
            span = max(zt - min(P["skirt_front"][2], P["skirt_back"][2]), 0.01)
            t = min(max((zt - p.z) / span, 0.0), 1.0)
            s = min(max(0.5 + p.x / 0.08, 0.0), 1.0)
            leg = P["leg"] * min(1.0, 1.15 * t ** 0.7)  # a robe (Mage body) barely follows the legs
            w = {"hips": 1.0 - leg, "upperleg.l": leg * s, "upperleg.r": leg * (1.0 - s)}
        else:
            w = weights_at(p) or {"chest": 1.0}
        for n, x in w.items():
            if x > 1e-3:
                groups[n].add([v.index], x, 'REPLACE')
    # thickness
    sol = ob.modifiers.new("thick", 'SOLIDIFY')
    sol.thickness = 0.02
    sol.offset = -1.0
    sol.use_rim = True
    sol.use_even_offset = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="thick")
    ob.select_set(False)
    ob.parent = rig
    arm = ob.modifiers.new("Armature", 'ARMATURE')
    arm.object = rig
    mat = bpy.data.materials.get("TabardCloth") or bpy.data.materials.new("TabardCloth")
    m.materials.append(mat)
    return ob


tab = make("Tabard", True)
front = make("Tabard_Front", False)
print("TABARD verts", len(tab.data.vertices), "tris", sum(len(p.vertices) - 2 for p in tab.data.polygons),
      "| front verts", len(front.data.vertices), "tris", sum(len(p.vertices) - 2 for p in front.data.polygons))

if PREVIEW:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    mat = bpy.data.materials["TabardCloth"]
    mat.diffuse_color = (0.15, 0.3, 0.85, 1)
    sc.render.resolution_x = 700
    sc.render.resolution_y = 700
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.parent == rig and not o.name.startswith("Tabard") and not o.name.startswith(MODEL + "_"):
            o.hide_render = True
        if o.name in (f"{MODEL}_Cape", f"{MODEL}_Helmet", "Knight_Helmet"):
            o.hide_render = True
    front.hide_render = True
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 1.6
    tgt = Vector((0, 0, 0.75))
    for nm, loc in [("front", (0.9, -5, 1.6)), ("back", (-0.9, 5, 1.6)), ("side", (5, 0, 1.0)), ("top", (0.4, 3.0, 5.0))]:
        cam.location = loc
        cam.rotation_euler = (tgt - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = f"{PREVIEW}/{MODEL.lower()}_{nm}.png"
        bpy.ops.render.render(write_still=True)

# export only the rig and the tabards
for o in bpy.data.objects:
    o.select_set(o in (rig, tab, front))
if rig.animation_data:
    rig.animation_data.action = None
rig.data.pose_position = 'POSE'
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format='GLB', export_skins=True,
                          export_animations=False, export_apply=False, export_materials='EXPORT',
                          export_texcoords=True, export_normals=True)
print("EXPORTED", OUT)
