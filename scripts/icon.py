"""Draws Easel's app icon: a cream easel holding a small painted landscape on raw umber.

    python3 scripts/icon.py App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024
TOP, BOTTOM = (140, 100, 64), (74, 49, 28)
CREAM, PAPER = (242, 231, 211), (251, 246, 236)


def gradient():
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img


def leg(d, p0, p1, w):
    d.line([p0, p1], fill=CREAM, width=w)
    for x, y in (p0, p1):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=CREAM)


img = gradient()
d = ImageDraw.Draw(img)

# Easel frame: back leg, two front legs, and the ledge.
leg(d, (512, 200), (512, 870), 26)
leg(d, (512, 176), (290, 872), 40)
leg(d, (512, 176), (734, 872), 40)
d.rounded_rectangle([322, 652, 702, 692], radius=14, fill=CREAM)

# Canvas shadow, then the canvas.
canvas_box = [344, 250, 680, 640]
shadow = Image.new("L", (S, S), 0)
ImageDraw.Draw(shadow).rounded_rectangle([b + o for b, o in zip(canvas_box, (10, 16, 10, 16))], radius=18, fill=120)
shadow = shadow.filter(ImageFilter.GaussianBlur(16))
img.paste((36, 22, 10), (0, 0), shadow)

# The painting, drawn on its own layer and clipped to the canvas.
painting = Image.new("RGB", (S, S), PAPER)
p = ImageDraw.Draw(painting)
p.ellipse([540, 316, 616, 392], fill=(228, 160, 58))
p.ellipse([250, 470, 620, 820], fill=(176, 92, 50))
p.ellipse([450, 500, 800, 840], fill=(112, 72, 40))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle(canvas_box, radius=16, fill=255)
img.paste(painting, (0, 0), mask)

img.save(sys.argv[1])
