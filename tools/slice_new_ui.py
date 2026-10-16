"""Cut Faisal's upgraded UI sheets (2026-10-14) into the game's assets.

    python3 tools/slice_new_ui.py <folder with showcase-2.png and cosmetic-atlas-1.png>

The sheets are one painted picture each (1536x1024 / 1614x974) on a dark
backdrop, so every piece is cut by its box, its backdrop removed and it is
scaled up to the size the game uses:
  * framed square icons (section 3): the symbol is lifted off its tile by
    keying out the tile's dark backdrop, so it sits on the HUD's own hex and
    round buttons like the old painted icons did;
  * shields, crests, banners, the stag: the backdrop is flood-filled away from
    the crop's edge and only the largest piece is kept (drops the labels);
  * class cards: kept opaque, scaled 2x;
  * store thumbnails: backdrop flood-filled away (it stops at the outlines).
Files are written over the old ones by name (git keeps the old ones).
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

OUT = "assets/ui/"

ICON_ROWS = [  # (y0, y1), tile x ranges, file names (None = no counterpart)
    ((594, 646), [(22, 69), (78, 125), (133, 179), (188, 235), (243, 290), (298, 344), (355, 402), (410, 457), (465, 512), (523, 574), (585, 635), (655, 708)],
     ["arrow", "artificer", "assassin", "assist", "bash", "blessing", "blink", "block", "bolt", "bramble", "bubble", "burst"]),
    ((650, 702), [(22, 70), (80, 126), (137, 191), (200, 246), (255, 305), (315, 364), (373, 421), (430, 478), (487, 545), (557, 622), (651, 708)],
     ["cape", "chest", "cleave", "cleric", "clock", "crown", "curse", "dagger", "darkpriest", "dodge", "drain"]),
    ((705, 757), [(22, 69), (79, 126), (139, 189), (197, 250), (259, 311), (321, 380), (388, 442), (452, 505), (515, 565), (575, 630), (651, 710)],
     ["fireball", "fist", "flag", "frost", "guard", "hammer", "lock", "mend", "might", "moon", "nightrunner"]),
    ((762, 815), [(22, 71), (82, 144), (153, 201), (210, 259), (269, 317), (326, 376), (385, 434), (444, 502), (516, 569), (581, 637), (650, 708)],
     ["overclock", "pierce", "potion", "pyromancer", "rank", "regen", "shard", "sharpshooter", "skull", "smite", "smoke"]),
    ((817, 865), [(22, 69), (76, 121), (130, 178), (187, 235), (243, 291), (301, 350), (358, 407), (412, 458), (470, 523), (533, 580), (590, 642), (653, 708)],
     ["snipe", "sword", "takedown", "trap", "trapper", "turret", "upgrade", "vanguard", "vigor", "volley", "warden", "wave"]),
    ((868, 917), [(22, 66), (72, 116), (124, 164), (171, 209), (215, 255), (260, 299), (304, 341), (348, 384), (392, 432), (439, 481), (491, 529), (536, 575), (581, 621), (629, 664), (671, 709)],
     ["xp", None, None, None, None, None, None, "menu/icon_appearance", "menu/icon_book", "menu/icon_check", "menu/icon_emblem", "menu/icon_exit", "menu/icon_face", "menu/icon_gamepad", "menu/icon_lock"]),
    ((921, 980), [(24, 70), (82, 137), (150, 196), (208, 261), (271, 320)],
     ["menu/icon_skull", "menu/icon_swords", "menu/icon_trophy", "menu/icon_tunic", "menu/icon_wait"]),
]
# (The sixth row's hex-skill pieces stay: the action bar draws its own hex art for them.)

CUTOUTS = [  # name, box (x, y, w, h) on showcase-2, output size (longest side)
    ("icons/class_knight", (32, 89, 86, 92), 256), ("icons/class_ranger", (128, 90, 80, 92), 256),
    ("icons/class_mage", (223, 89, 77, 92), 256), ("icons/class_healer", (320, 89, 79, 92), 256),
    ("icons/class_engineer", (416, 91, 79, 90), 256), ("icons/class_rogue", (511, 89, 83, 92), 256),
    ("icons/class_elf", (617, 89, 82, 92), 256), ("icons/class_human", (719, 91, 80, 90), 256),
    ("skills/shield_elf", (30, 402, 80, 97), 288), ("skills/shield_human", (127, 402, 77, 97), 288),
    ("cards/crest_elf", (866, 73, 180, 193), 380), ("cards/crest_human", (1041, 76, 166, 189), 380),
    ("cards/logo_elves", (866, 73, 180, 193), 880), ("cards/logo_humans", (1041, 76, 166, 189), 880),
    ("icons/crest_forest", (1242, 99, 124, 131), 256), ("icons/crest_kingdom", (1381, 107, 125, 123), 256),
    ("menu/banner_tree", (864, 273, 77, 149), 512),
    ("menu/banner_lion", (1021, 273, 79, 149), 512), ("menu/banner_crown_red", (1102, 275, 75, 147), 512),
    ("menu/banner_crown_blue", (1182, 275, 74, 147), 512), ("menu/icon_stag", (1351, 266, 142, 114), 96),
]

CARDS = [  # class card box on showcase-2, the classes it serves (both factions)
    ((31, 218, 121, 177), "knight"), ((160, 218, 121, 178), "ranger"), ((290, 218, 126, 178), "mage"),
    ((424, 223, 125, 173), "healer"), ((557, 226, 123, 170), "engineer"), ((687, 217, 125, 178), "rogue"),
]

STORE_NAMES = ["cape_1", "cape_2", "cape_3", "cape_4", "cape_5", "hair_0", "hair_1", "hair_10", "hair_11", "hair_2", "hair_3", "hair_4",
    "hair_5", "hair_6", "hair_7", "hair_8", "hair_9", "hair_style_0", "hair_style_1", "hair_style_2", "hair_style_3", "hair_style_4", "hat_1", "hat_2",
    "hat_3", "hat_4", "hat_5", "hat_6", "hat_7", "outfit_1", "outfit_2", "outfit_3", "outfit_4", "outfit_5", "outfit_6", "trim_0",
    "trim_1", "trim_10", "trim_11", "trim_2", "trim_3", "trim_4", "trim_5", "trim_6", "trim_7", "trim_8", "trim_9", "weapon_1",
    "weapon_2", "weapon_3", "weapon_4", "weapon_5", "weapon_6"]


def backdrop(a, lo=20, hi=62):
    mx = a.max(2).astype(int)
    mn = a.min(2).astype(int)
    return ((mx - mn) < 22) & (mx < hi) & (mx >= lo)


def glyph(tile, inset=0.13, out=128, lo=26, hi=70):
    w, h = tile.size
    ix, iy = int(w * inset), int(h * inset)
    t = tile.crop((ix, iy, w - ix, h - iy)).resize((out, out), Image.LANCZOS)
    a = np.asarray(t).astype(float)
    ring = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
    bg = np.median(ring, 0)
    d = np.sqrt(((a - bg) ** 2).sum(2))
    al = np.clip((d - lo) / (hi - lo), 0, 1)
    yy, xx = np.mgrid[0:out, 0:out]
    e = np.minimum.reduce([xx, yy, out - 1 - xx, out - 1 - yy])
    al *= np.clip(e / 6.0, 0, 1)
    rgb = np.where(al[..., None] > 0.02, (a - bg * (1 - al[..., None])) / np.maximum(al[..., None], 0.02), a)
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), al * 255]).astype(np.uint8), "RGBA")


def cutout(img, box, pad=4, keep_largest=True, key=(20, 62)):
    x, y, w, h = box
    c = img.crop((x - pad, y - pad, x + w + pad, y + h + pad))
    a = np.asarray(c).astype(int)
    bg = backdrop(a, *key)
    seed = np.zeros_like(bg)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    lab, _ = ndimage.label(bg)
    outside = np.isin(lab, np.unique(lab[seed & bg]))
    outside &= bg
    fg = ~outside
    if keep_largest:
        l2, n = ndimage.label(fg)
        if n > 1:
            sizes = ndimage.sum(fg, l2, range(1, n + 1))
            fg = l2 == (1 + int(np.argmax(sizes)))
    al = ndimage.gaussian_filter(fg.astype(float), 0.7)
    out = np.dstack([a, np.clip(al * 255, 0, 255)]).astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    return im.crop(im.getbbox())


def upscale(im, longest):
    s = longest / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    return im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=60, threshold=2))


def main(folder):
    sheet = Image.open(folder + "/showcase-2.png").convert("RGB")
    atlas = Image.open(folder + "/cosmetic-atlas-1.png").convert("RGB")
    done = []
    for (y0, y1), xs, names in ICON_ROWS:
        for (x0, x1), name in zip(xs, names):
            if name:
                path = OUT + (name if "/" in name else "icons/" + name) + ".png"
                g = glyph(sheet.crop((x0, y0, x1, y1)), out=96 if name.startswith("menu/") else 128)
                g.save(path)
                done.append(path)
    for name, box, size in CUTOUTS:
        path = OUT + name + ".png"
        upscale(cutout(sheet, box), size).save(path)
        done.append(path)
    for (x, y, w, h), cls in CARDS:
        card = upscale(sheet.crop((x, y, x + w, y + h)).convert("RGBA"), 372)
        for side in ["elf", "human"]:
            path = OUT + "cards/%s_%s.png" % (side, cls)
            card.save(path)
            done.append(path)
    # The store atlas: find each thumbnail, read them in grid order.
    a = np.asarray(atlas).astype(int)[100:960, 10:1605]
    fg = ndimage.binary_opening(~backdrop(a, 22, 60), iterations=2)
    lab, _ = ndimage.label(fg)
    boxes = []
    for sl in ndimage.find_objects(lab):
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if h >= 55 and w >= 40:
            boxes.append((sl[1].start + 10, sl[0].start + 100, w, h))
    boxes.sort(key=lambda b: ((b[1] - 100) // 150, b[0]))
    assert len(boxes) == len(STORE_NAMES), len(boxes)
    for box, name in zip(boxes, STORE_NAMES):
        # Black hair is the backdrop's own colour: key it tighter.
        t = cutout(atlas, box, pad=3, key=(26, 52) if name == "hair_2" else (20, 62))
        canvas = Image.new("RGBA", (256, 256))
        t = upscale(t, 236)
        canvas.alpha_composite(t, ((256 - t.width) // 2, 256 - t.height - 6))
        path = OUT + "store/%s.png" % name
        canvas.save(path)
        done.append(path)
    print("%d files written" % len(done))


if __name__ == "__main__":
    main(sys.argv[1])
