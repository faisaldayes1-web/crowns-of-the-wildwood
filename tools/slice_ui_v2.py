"""Cut Faisal's second set of UI sheets (2026-10-14 07:40, "heres the 2k
textures") into the game's assets.

    python3 tools/slice_ui_v2.py <folder with page1.png .. page4.png>

page1 = class icons, class cards, ability shields, crests
page2 = faction logos, crests, banners, the stag
page3 = every other icon (abilities, upgrades, HUD, menus)
page4 = store thumbnails

Every sheet is 1672x941 with its pieces laid out on a dark checker backdrop
and a file name printed under each. A piece is cut by its cell (the part
above its label), the backdrop is flood-filled away from the cell's edge,
specks are dropped, and the piece is centred on a canvas of the size the
sheet names. Files are written over the old ones by name (git keeps them).
Kept from the first set: the title logo and topbar (higher resolution
there), the action bar's hex skill art, the body-shape menu icons and
store trim_0 (not on these sheets).
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

OUT = os.environ.get("UI_OUT", "assets/ui/")


def backdrop(a):
    mx = a.max(2)
    mn = a.min(2)
    return (mx - mn < 16) & (mx < 56) & (mx >= 24)


def cut(img, box):
    """The piece inside box (x0, y0, x1, y1) with the backdrop made clear.
    The flood from the cell's edge eats the checker and the dark halo round
    a piece (any dark pixel that is not the black outline); bits of a
    neighbour or a header touching the cell's edge are dropped, as are specks."""
    crop = img.crop(box)
    a = np.asarray(crop).astype(int)
    mx = a.max(2)
    lab, _ = ndimage.label(backdrop(a))
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    clear = np.isin(lab, list(edge))
    halo = (mx < 84) & (mx >= 22) & ((mx - a.min(2)) < 48)
    for _ in range(4):   # the halo is a few pixels wide; dark parts inside stay
        clear |= ndimage.binary_dilation(clear) & halo
    fg = ndimage.binary_opening(~clear, iterations=1)
    fl, n = ndimage.label(fg)
    if n == 0:
        return None
    sizes = ndimage.sum(fg, fl, range(1, n + 1))
    big = int(np.argmax(sizes)) + 1
    border = set(np.unique(np.concatenate([fl[0], fl[-1], fl[:, 0], fl[:, -1]]))) - {0}
    objs = ndimage.find_objects(fl)
    ok = [i + 1 for i, sz in enumerate(sizes) if i + 1 == big or (sz >= max(40, 0.06 * sizes.max()) and i + 1 not in border
        and objs[i][0].stop - objs[i][0].start >= 14)]   # (no header rules)
    keep = ndimage.binary_fill_holes(np.isin(fl, ok))
    # Soften the rim: a pixel one step outside keeps a little, dark rims fade.
    alpha = keep.astype(float)
    rim = keep & ~ndimage.binary_erosion(keep, iterations=1)
    alpha[rim] = np.clip((mx[rim] - 20) / 60.0, 0.35, 1.0)
    al = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    rgba = crop.convert("RGBA")
    rgba.putalpha(al)
    bb = Image.fromarray((keep * 255).astype(np.uint8)).getbbox()
    return rgba.crop(bb) if bb else None


def place(piece, size, fill=0.94):
    """piece scaled to fit size (w, h) * fill and centred on a clear canvas."""
    w, h = size
    k = min(w * fill / piece.width, h * fill / piece.height)
    p = piece.resize((max(1, round(piece.width * k)), max(1, round(piece.height * k))), Image.LANCZOS)
    c = Image.new("RGBA", size, (0, 0, 0, 0))
    c.alpha_composite(p, ((w - p.width) // 2, (h - p.height) // 2))
    return c


def fit(piece, longest):
    k = longest / max(piece.size)
    return piece.resize((round(piece.width * k), round(piece.height * k)), Image.LANCZOS)


def save(im, name):
    os.makedirs(os.path.dirname(OUT + name), exist_ok=True)
    im.save(OUT + name + ".png")


# page1 --------------------------------------------------------------------
CLASS_X = [128, 328, 529, 731, 937, 1139, 1342, 1543]
CLASS_NAMES = ["knight", "ranger", "mage", "healer", "engineer", "rogue", "elf", "human"]
CARD_X = [(17, 201), (224, 409), (431, 616), (639, 824), (847, 1032), (1054, 1239), (1262, 1447), (1468, 1653)]
SHIELD_X = [75, 200, 325, 451, 580, 708, 832, 957]


def page1(img):
    for x, n in zip(CLASS_X, CLASS_NAMES):
        p = cut(img, (x - 80, 148, x + 80, 292))
        save(place(p, (256, 256), 0.97), "icons/class_" + n)
    for (x0, x1), n in zip(CARD_X, CLASS_NAMES):
        p = cut(img, (x0 - 6, 368, x1 + 6, 645))
        card = fit(p, 380)
        base = "base" if n in ("elf", "human") else n
        for f in (["elf", "human"] if base != "base" else [n]):
            save(card, "cards/%s_%s" % (f, base))
    # The scoreboard shields: the Elf and Human ability shields.
    for x, n in zip(SHIELD_X[6:], ["elf", "human"]):
        p = cut(img, (x - 62, 724, x + 62, 852))
        save(fit(p, 288), "skills/shield_" + n)


# page2 --------------------------------------------------------------------
PAGE2 = [  # name, box, longest side
    ("cards/logo_elves", (14, 96, 290, 425), 880), ("cards/logo_humans", (294, 112, 576, 425), 880),
    ("cards/crest_elf", (588, 112, 882, 425), 380), ("cards/crest_human", (884, 112, 1160, 425), 380),
    ("icons/crest_forest", (1170, 150, 1395, 412), 256), ("icons/crest_kingdom", (1428, 150, 1648, 412), 256),
    ("menu/banner_tree", (28, 492, 216, 735), 512), ("menu/banner_lion", (250, 492, 438, 735), 512),
    ("menu/banner_crown_red", (490, 492, 680, 735), 512), ("menu/banner_crown_blue", (725, 492, 915, 735), 512),
]


def page2(img):
    for name, box, longest in PAGE2:
        p = cut(img, box)
        if name.startswith("icons/"):
            save(place(p, (longest, longest), 0.97), name)
        elif name.startswith("menu/banner"):
            save(place(p, (256, 512), 0.98), name)
        else:
            save(fit(p, longest), name)
    save(place(cut(img, (975, 545, 1165, 728)), (96, 96), 0.96), "menu/icon_stag")


# page3 --------------------------------------------------------------------
COLS = [70, 207, 345, 484, 625, 765, 903, 1042, 1181, 1320, 1461, 1600]
ICON_ROWS = [  # (y0, y1) above the labels, names in column order (None = skip)
    ((96, 192), ["arrow", "artificer", "assassin", "assist", "bash", "blessing", "blink", "block", "bolt", "bramble", "bubble", "burst"]),
    ((226, 320), ["cape", "chest", "cleave", "cleric", "clock", "coin", "crown", "curse", "dagger", "darkpriest", "dodge", "drain"]),
    ((355, 450), ["fireball", "fist", "flag", "frost", "frostweaver", "guard", "hammer", "lock", "mend", "might", "moon", "nightrunner"]),
    ((485, 580), ["overclock", "pierce", "potion", "pyromancer", "rank", "regen", "shard", "sharpshooter", "siegewright", "skull", "smite", "smoke"]),
    ((610, 704), ["snipe", "sword", "takedown", "trap", "trapper", "turret", "upgrade", "vanguard", "vigor", "volley", "warden", "wave"]),
]
MENU_ICONS = [  # x centre, y range, name (96 px)
    (905, (745, 810), "icon_appearance"), (1035, (745, 810), "icon_arrow_left"), (1173, (745, 810), "icon_arrow_right"),
    (68, (848, 906), "icon_book"), (157, (848, 906), "icon_check"), (248, (848, 906), "icon_crown"),
    (338, (848, 906), "icon_emblem"), (436, (848, 906), "icon_exit"), (548, (848, 906), "icon_face"),
    (652, (848, 906), "icon_gamepad"), (752, (848, 906), "icon_gear"), (845, (848, 906), "icon_hair"),
    (937, (848, 906), "icon_lock"), (1047, (848, 906), "icon_palette"), (1160, (848, 906), "icon_skull"),
    (1250, (848, 906), "icon_swords"), (1338, (848, 906), "icon_trophy"), (1517, (848, 906), "icon_tunic"),
    (1613, (848, 906), "icon_wait"),
]


def page3(img):
    for (y0, y1), names in ICON_ROWS:
        for x, n in zip(COLS, names):
            if n:
                save(place(cut(img, (x - 68, y0, x + 68, y1)), (256, 256), 0.96), "icons/" + n)
    save(place(cut(img, (20, 742, 122, 812)), (256, 256), 0.96), "icons/xp")
    for x, (y0, y1), n in MENU_ICONS:
        save(place(cut(img, (x - 44, y0, x + 44, y1)), (96, 96), 0.96), "menu/" + n)


# page4 --------------------------------------------------------------------
STORE_ROWS = [  # (y0, y1), half width, [(x, name)]
    ((128, 268), 64, [(75, "cape_1"), (207, "cape_2"), (347, "cape_3"), (489, "cape_4"), (630, "cape_5"),
        (803, "hair_0"), (935, "hair_1"), (1062, "hair_10"), (1190, "hair_11"), (1323, "hair_2"), (1455, "hair_3"), (1583, "hair_4")]),
    ((350, 492), 64, [(75, "hair_5"), (207, "hair_6"), (335, "hair_7"), (470, "hair_8"), (605, "hair_9"),
        (765, "hair_style_0"), (905, "hair_style_1"), (1040, "hair_style_2"), (1172, "hair_style_3"), (1318, "hair_style_4"),
        (1453, "hat_1"), (1585, "hat_2")]),
    ((562, 713), 66, [(72, "hat_3"), (208, "hat_4"), (345, "hat_5"), (497, "hat_6"), (632, "hat_7"),
        (798, "outfit_1"), (950, "outfit_2"), (1100, "outfit_3"), (1250, "outfit_4"), (1400, "outfit_5"), (1560, "outfit_6")]),
    ((785, 898), 43, [(63, "trim_1"), (150, "trim_10"), (236, "trim_11"), (323, "trim_2"), (410, "trim_3"), (497, "trim_4"),
        (582, "trim_5"), (668, "trim_6"), (755, "trim_7"), (841, "trim_8"), (928, "trim_9")]),
    ((785, 898), 52, [(1040, "weapon_1"), (1145, "weapon_2"), (1250, "weapon_3"), (1357, "weapon_4"), (1462, "weapon_5")]),
    ((785, 898), 62, [(1575, "weapon_6")]),
]


HEADERS4 = [(240, 88, 650, 131), (1015, 88, 1445, 131), (240, 318, 600, 359), (970, 318, 1405, 359),
    (235, 540, 575, 580), (970, 540, 1405, 580), (280, 756, 630, 797), (1150, 756, 1495, 797)]


def page4(img):
    # Paint the section headers out first (the witch hat's purple tip,
    # which pokes into HATS, survives).
    a = np.asarray(img).copy()
    for x0, y0, x1, y1 in HEADERS4:
        r = a[y0:y1, x0:x1].astype(int)
        kill = ~(r[..., 2] > r[..., 0] + 10)
        r[kill] = (34, 29, 24)
        a[y0:y1, x0:x1] = r.astype(np.uint8)
    img = Image.fromarray(a)
    for (y0, y1), hw, items in STORE_ROWS:
        for x, n in items:
            save(place(cut(img, (x - hw, y0, x + hw, y1)), (256, 256), 0.92), "store/" + n)


def main(folder):
    for i, fn in enumerate([page1, page2, page3, page4]):
        fn(Image.open("%s/page%d.png" % (folder, i + 1)).convert("RGB"))


if __name__ == "__main__":
    main(sys.argv[1])
