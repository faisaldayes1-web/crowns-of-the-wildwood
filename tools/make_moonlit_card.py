"""Moonlit Wildwood's map card: the Wildwood card (the same valley) graded to
night, so the card shows the map's real layout (the old card was a render
of an earlier layout). claude-faisal/crowns-visual 2026-11-04.

    python tools/make_moonlit_card.py
"""
from PIL import Image, ImageEnhance, ImageFilter, ImageChops

SRC = "assets/ui/menu/map_wildwood.png"
OUT = "assets/ui/menu/map_moonlit.png"

day = Image.open(SRC).convert("RGB")
night = ImageEnhance.Color(day).enhance(0.7)
night = ImageEnhance.Brightness(night).enhance(0.66)
r, g, b = night.split()
night = Image.merge("RGB", (r.point(lambda v: v * 0.72), g.point(lambda v: v * 0.9), b.point(lambda v: min(255, v * 1.25 + 14))))
# Lamps and crystals keep a warm glow: the brightest day pixels bloom back in.
glow = day.point(lambda v: 255 if v > 235 else 0).convert("L").filter(ImageFilter.GaussianBlur(3))
warm = Image.new("RGB", day.size, (255, 196, 110))
night = Image.composite(ImageChops.screen(night, warm), night, glow.point(lambda v: v * 0.55))
night.save(OUT)
print("wrote", OUT, night.size)
