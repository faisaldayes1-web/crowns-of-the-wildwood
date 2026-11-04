"""Agent: Codex-faisal2. Assemble actual-frame comparisons and check receipts."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

out = Path(__file__).resolve().parents[1] / 'docs/visual/2026-10-30-vfx-layers'
font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 24)
sheet = Image.new('RGB', (1600, 920), '#171c22')
draw = ImageDraw.Draw(sheet)
for index, (name, title) in enumerate([('before', 'BEFORE - independently rotated layers'),
                                       ('after', 'AFTER - one shared rotation')]):
    frame = Image.open(out/name/'rune-gameplay.png').convert('RGB')
    assert frame.size == (1280, 720)
    x = index*800
    draw.text((x+12, 10), title, font=font, fill='#f4e6c8')
    sheet.paste(frame.resize((800, 450), Image.Resampling.LANCZOS), (x, 44))
    draw.text((x+12, 508), 'Same rune region, enlarged for inspection', font=font, fill='#f4e6c8')
    crop = frame.crop((650, 380, 830, 535))
    sheet.paste(crop.resize((420, 362), Image.Resampling.NEAREST), (x+190, 548))
sheet.save(out/'rune-before-after.jpg', quality=95)
records = {name: json.loads((out/name/'result.json').read_text())
           for name in ['before', 'after', 'night', 'compatibility']}
assert records['before']['failures'] == 4
assert records['before']['observations'][0]['yaw_difference_radians'] > 2.8
for name in ['after', 'night', 'compatibility']:
    assert records[name]['failures'] == 0
assert records['night']['layers'] == 1 and not records['night']['daylight']
assert all(row['yaw_difference_radians'] == 0 for row in records['after']['observations'])
print('PASS: negative control fails all four alignment samples; fixed day/GL/night checks pass')
