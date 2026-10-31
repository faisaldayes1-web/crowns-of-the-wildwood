"""Agent: Codex-faisal2. Assemble unretouched engine captures for PR review."""
from pathlib import Path
import hashlib
import json
import sys
from PIL import Image, ImageDraw, ImageFont

repo = Path(__file__).resolve().parents[1]
out = repo / 'docs/visual/2026-10-30-map-cards'
if '--prepare-textures' in sys.argv:
    # Supersample the local renders down before the UI's final reduction.
    # This avoids single-pixel flowers/grass aliasing at small card sizes.
    for name in ['wildwood', 'moonlit', 'stonekeep', 'ember']:
        Image.open(out/name/'card.png').resize((512, 480), Image.Resampling.LANCZOS).save(
            repo / f'assets/ui/menu/map_{name}.png')
    print('Prepared four antialiased 512x480 textures from 1024x960 engine renders')
    sys.exit(0)
target = Path('C:/Games/ORY-Candidates/Crowns/visual-pass/world/triptych/02-map-hall.png')
font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 24)
sheet = Image.new('RGB', (2328, 480), '#171c22')
draw = ImageDraw.Draw(sheet)
ref = Image.open(target).convert('RGB')
# Exact right-hand selected target from the supplied 2920x610 triptych.
assert ref.size == (2920, 610)
panels = [Image.open(out/'wildwood/select-screen.png'),
          Image.open(out/'after/select-screen.png'), ref.crop((1950, 60, 2910, 600))]
for i, (label, panel) in enumerate(zip(['BEFORE - main 0158a9c', 'AFTER - actual map renders', 'PICKED TARGET - supplied reference'], panels)):
    x = 8 + i * 776
    draw.text((x, 10), label, font=font, fill='#f8ebce')
    sheet.paste(panel.convert('RGB').resize((768, 432), Image.Resampling.LANCZOS), (x, 42))
sheet.save(out/'map-select-triptych.jpg', quality=94)

records = []
for name in ['wildwood', 'moonlit', 'stonekeep', 'ember']:
    card = repo / f'assets/ui/menu/map_{name}.png'
    expected = Image.open(out/name/'card.png').resize((512, 480), Image.Resampling.LANCZOS)
    assert Image.open(card).tobytes() == expected.tobytes()
    assert Image.open(card).size == (512, 480)
    bounds = json.loads((out/name/'bounds.json').read_text())
    for kind in ['clean', 'labelled']:
        assert Image.open(out/name/f'map-{kind}-4096.png').size == (4096, 2304)
    for point in bounds['landmarks']:
        assert abs(point['pixel_x'] - (point['world_x']+108)/216*4096) < .01
        assert abs(point['pixel_y'] - (point['world_z']+60.75)/121.5*2304) < .01
    records.append({'map': name, 'texture': str(card.relative_to(repo)).replace('\\', '/'),
                    'sha256': hashlib.sha256(card.read_bytes()).hexdigest(), 'bounds_verified': True})
(out/'manifest.json').write_text(json.dumps({'agent': 'Codex-faisal2', 'geometry_source': '0158a9c',
    'renderer': 'Godot 4.3 official, Forward+, NVIDIA RTX 5080 Laptop',
    'target_sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'maps': records}, indent=2)+'\n')
print('PASS: four filtered texture derivatives, card/export dimensions, all landmark coordinate mappings')
