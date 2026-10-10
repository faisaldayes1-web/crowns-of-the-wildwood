"""Crop gameplay renders into the TUTORIAL pictures (one per Guide topic).

    python3 tools/make_tutorial_images.py <render_dir>

<render_dir> holds t0.png .. t5.png, 1920x1080 renders of real matches:
  t0  the pause MAP (the whole battlefield)    --play --debug-menu --debug-tab=0
  t1  a fight (combat showcase)                --play --fxshow --debug-nohud
  t2  the courtyard's class stations           --play --debug-nohud --debug-zoom=0.8
  t3  the UPGRADES board                       --play --debug-rank --debug-role=2
  t4  carrying the enemy crown                 --play --debug-carry --debug-at=0,0 --debug-nohud
  t5  the middle of the map from above         --play --debug-nohud --debug-zoom=2.0 --debug-cam=0,0
Each is cropped to 16:9 around its subject and saved as
assets/ui/tutorial/topic_N.jpg at 640x360.
"""
import sys
from PIL import Image

# Crop boxes (left, top, right, bottom) in render pixels; None = whole frame.
CROPS = {0: (225, 320, 1275, 911), 1: (240, 135, 1680, 945), 2: None, 3: (180, 150, 1740, 1028), 4: (480, 180, 1440, 720), 5: None}


def main():
    src = sys.argv[1]
    for i in range(6):
        im = Image.open("%s/t%d.png" % (src, i)).convert("RGB")
        if CROPS[i]:
            im = im.crop(CROPS[i])
        im.resize((640, 360), Image.LANCZOS).save("assets/ui/tutorial/topic_%d.jpg" % i, quality=88)


if __name__ == "__main__":
    main()
