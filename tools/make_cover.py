#!/usr/bin/env python3
"""Draws the itch.io cover from scratch (no screenshot): a poster of the table, the cards, the candles and the chips.
Usage: python3 tools/make_cover.py   ->  docs/itch/cover_630x500.png and cover_1260x1000.png
Needs Pillow and numpy. Assets used: the chip pictures of the game and the Rye font."""
import glob
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "docs", "itch")
W, H = 1260, 1000
RYE = glob.glob(os.path.join(ROOT, "assets", "fonts", "rye", "*.ttf"))[0]
SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
rng = random.Random(7)


def font(path, size):
    return ImageFont.truetype(path, size)


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def over(base, top):
    return Image.alpha_composite(base, top)


def glow(img, radius, strength=1.0):
    blurred = img.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        a = blurred.getchannel("A").point(lambda v: min(255, int(v * strength)))
        blurred.putalpha(a)
    return blurred


def shadow_of(img, offset, radius, alpha=170):
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(radius)).point(lambda v: v * alpha // 255)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(a)
    out = layer()
    out.paste(sh, offset, sh)
    return out


def background():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    base = np.zeros((H, W, 3), np.float32)
    base[:] = (10, 5, 17)
    d = np.sqrt(((x - W / 2) / 760) ** 2 + ((y - 380) / 560) ** 2)
    purple = np.clip(1 - d, 0, 1) ** 1.6
    base += purple[..., None] * np.array([62, 30, 92], np.float32)
    d2 = np.sqrt(((x - W / 2) / 900) ** 2 + ((y - 1100) / 420) ** 2)
    red = np.clip(1 - d2, 0, 1) ** 1.4
    base += red[..., None] * np.array([105, 12, 20], np.float32)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def spotlight():
    out = layer()
    d = ImageDraw.Draw(out)
    d.polygon([(560, -40), (700, -40), (1010, 760), (250, 760)], fill=(210, 190, 255, 38))
    return glow(out, 38)


def felt():
    out = layer()
    d = ImageDraw.Draw(out)
    d.ellipse((-260, 640, W + 260, 1300), fill=(30, 36, 26, 255), outline=(150, 100, 30, 255), width=10)
    d.ellipse((-200, 690, W + 200, 1250), outline=(120, 80, 25, 160), width=3)
    # light pool on the felt
    pool = layer()
    ImageDraw.Draw(pool).ellipse((200, 700, W - 200, 1010), fill=(120, 105, 70, 120))
    return over(out, glow(pool, 55))


def felt_edge(x):
    """The y of the felt's far rim at x (the felt is an ellipse centred at (630, 970), radii 890 and 330)."""
    return 970 - 330 * math.sqrt(max(0.0, 1 - ((x - 630) / 890) ** 2))


def candle(x, h):
    y = felt_edge(x) + 26
    out = layer()
    d = ImageDraw.Draw(out)
    d.ellipse((x - 34, y - 9, x + 34, y + 11), fill=(0, 0, 0, 150))
    d.ellipse((x - 22, y - 7, x + 22, y + 7), fill=(215, 205, 185, 255))
    d.rectangle((x - 16, y - h, x + 16, y), fill=(236, 226, 205, 255))
    d.rectangle((x - 16, y - h, x - 6, y), fill=(255, 250, 235, 255))
    d.ellipse((x - 16, y - h - 7, x + 16, y - h + 7), fill=(245, 240, 225, 255))
    d.line((x, y - h - 4, x, y - h - 14), fill=(30, 20, 20, 255), width=3)
    flame = layer()
    fd = ImageDraw.Draw(flame)
    fd.ellipse((x - 11, y - h - 56, x + 11, y - h - 8), fill=(255, 190, 70, 255))
    fd.ellipse((x - 6, y - h - 42, x + 6, y - h - 12), fill=(255, 245, 190, 255))
    halo = layer()
    ImageDraw.Draw(halo).ellipse((x - 70, y - h - 120, x + 70, y - h + 20), fill=(255, 160, 50, 70))
    return over(over(out, glow(halo, 24)), flame)


def card(w, h, rank, suit, red):
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    ink = (150, 20, 35, 255) if red else (24, 12, 40, 255)
    d.rounded_rectangle((0, 0, w - 1, h - 1), 22, fill=(236, 226, 246, 255), outline=(70, 36, 110, 255), width=6)
    d.rounded_rectangle((16, 16, w - 17, h - 17), 14, outline=(150, 120, 190, 255), width=2)
    f = font(SERIF, 70)
    d.text((34, 24), rank, font=f, fill=ink)
    d.text((34, 98), suit, font=font(SANS, 62), fill=ink)
    big = font(SANS, 230)
    d.text((w / 2, h / 2 + 8), suit, font=big, fill=ink, anchor="mm")
    idx = Image.new("RGBA", (110, 170), (0, 0, 0, 0))
    idd = ImageDraw.Draw(idx)
    idd.text((0, 0), rank, font=f, fill=ink)
    idd.text((0, 74), suit, font=font(SANS, 62), fill=ink)
    idx = idx.rotate(180)
    c.paste(idx, (w - 34 - 110, h - 24 - 170), idx)
    return c


def place(base, img, center, angle, shade=True):
    r = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    lay = layer()
    pos = (int(center[0] - r.width / 2), int(center[1] - r.height / 2))
    if shade:
        lay = over(lay, shadow_of_on(r, pos))
    lay.paste(r, pos, r)
    return over(base, lay)


def shadow_of_on(r, pos):
    out = layer()
    sh = shadow_of(r, (14, 22), 16, 190)
    out.paste(sh, pos, sh)
    return out


def chip_stack(base, name, cx, cy, n, size=250, squash=0.5):
    chip = Image.open(os.path.join(ROOT, "assets", "art", "casino", "chips", name)).convert("RGBA")
    mask = Image.new("L", chip.size, 0)
    ImageDraw.Draw(mask).ellipse((6, 6, chip.width - 7, chip.height - 7), fill=255)
    chip.putalpha(ImageChops.multiply(chip.getchannel("A"), mask))
    chip = chip.resize((size, size), Image.LANCZOS).resize((size, int(size * squash)), Image.LANCZOS)
    thick = 18
    lay = layer()
    for i in range(n):
        y = cy - i * thick
        side = Image.new("RGBA", chip.size, (0, 0, 0, 0))
        side_d = ImageDraw.Draw(side)
        side_d.ellipse((0, 0, chip.width - 1, chip.height - 1), fill=(40, 20, 70, 255))
        side_d.rectangle((0, chip.height / 2, chip.width, chip.height / 2 + thick), fill=(0, 0, 0, 0))
        for k in range(thick, 0, -3):
            lay.paste(side, (int(cx - chip.width / 2), int(y + k)), side)
        lay.paste(chip, (int(cx - chip.width / 2), int(y)), chip)
    return over(base, over(shadow_on_whole(lay), lay))


def shadow_on_whole(lay):
    return shadow_of(lay, (10, 20), 14, 170)


def blood(base, cx, cy):
    out = layer()
    d = ImageDraw.Draw(out)
    d.ellipse((cx - 250, cy - 60, cx + 220, cy + 70), fill=(105, 8, 14, 235))
    for _ in range(24):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(150, 360)
        px, py = cx + math.cos(a) * r * 1.1, cy + math.sin(a) * r * 0.35
        s = rng.uniform(4, 15)
        d.ellipse((px - s, py - s * 0.6, px + s, py + s * 0.6), fill=(125, 10, 16, 240))
    for _ in range(14):
        a = rng.uniform(math.pi * 1.05, math.pi * 1.95)
        r = rng.uniform(80, 240)
        px, py = cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.9 - 20
        s = rng.uniform(3, 9)
        d.ellipse((px - s, py - s, px + s, py + s * 1.5), fill=(150, 12, 20, 255))
    sheen = layer()
    ImageDraw.Draw(sheen).ellipse((cx - 120, cy - 30, cx + 40, cy - 6), fill=(255, 140, 140, 60))
    return over(over(base, out), glow(sheen, 6))


def finger(base, cx, cy):
    """A pale finger lying on the felt: a nail, creases, a gold ring and a bloody, cut root."""
    w, h = 640, 190
    skin = (226, 176, 154, 255)
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    # a slightly tapering finger: thicker at the root (left), a rounded tip (right)
    bd.polygon([(60, 38), (w - 120, 52), (w - 120, h - 52), (60, h - 38)], fill=skin)
    bd.ellipse((w - 190, 52, w - 36, h - 52), fill=skin)
    bd.ellipse((30, 38, 100, h - 38), fill=skin)
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for yy in range(h):
        t = (yy - 38) / (h - 76)
        if 0 <= t <= 1:
            if t < 0.45:
                sd.line([(0, yy), (w, yy)], fill=(255, 235, 225, int(110 * (0.45 - t) / 0.45)))
            else:
                sd.line([(0, yy), (w, yy)], fill=(120, 50, 50, int(150 * (t - 0.45) / 0.55)))
    shade.putalpha(ImageChops.multiply(shade.getchannel("A"), body.getchannel("A")))
    f = over(body, shade)
    fd = ImageDraw.Draw(f)
    for xx in (230, 380):  # knuckle creases
        for k in (-10, 0, 10):
            fd.arc((xx - 8 + k // 2, 52, xx + 8 + k // 2, h - 52), 100, 260, fill=(150, 90, 84, 255), width=3)
    # the nail
    fd.rounded_rectangle((w - 150, 66, w - 62, h - 66), 30, fill=(238, 196, 190, 255), outline=(170, 110, 104, 255), width=3)
    fd.rounded_rectangle((w - 140, 72, w - 100, 92), 8, fill=(255, 240, 236, 200))
    # gold ring
    fd.rounded_rectangle((112, 30, 160, h - 30), 12, fill=(222, 160, 50, 255), outline=(120, 76, 14, 255), width=4)
    fd.rounded_rectangle((120, 38, 132, h - 38), 6, fill=(255, 225, 140, 255))
    # the cut root: raw flesh around a bone
    fd.ellipse((8, 34, 78, h - 34), fill=(140, 14, 20, 255), outline=(66, 6, 10, 255), width=4)
    fd.ellipse((26, 70, 54, h - 70), fill=(238, 224, 205, 255))
    f = f.rotate(-8, expand=True, resample=Image.BICUBIC)
    lay = layer()
    pos = (int(cx - f.width / 2), int(cy - f.height / 2))
    sh = shadow_of(f, (10, 26), 14, 200)
    lay.paste(sh, pos, sh)
    lay.paste(f, pos, f)
    return over(base, lay)


def title(base):
    lay = layer()
    d = ImageDraw.Draw(lay)
    big = font(RYE, 150)
    for text, y in (("BORROWED", 30), ("LUCK", 178)):
        d.text((W / 2, y), text, font=big, fill=(247, 168, 62, 255), anchor="ma", stroke_width=10, stroke_fill=(24, 8, 30, 255))
    halo = glow(lay, 22, 1.2)
    # the gold gets a lighter top edge
    hi = layer()
    hd = ImageDraw.Draw(hi)
    for text, y in (("BORROWED", 30), ("LUCK", 178)):
        hd.text((W / 2, y - 4), text, font=big, fill=(255, 222, 150, 110), anchor="ma")
    return over(over(base, halo), over(lay, hi))


def tagline(base):
    lay = layer()
    d = ImageDraw.Draw(lay)
    d.text((W / 2, 868), "Blackjack. Always all in.", font=font(RYE, 56), fill=(236, 226, 246, 255), anchor="ma", stroke_width=6, stroke_fill=(20, 6, 28, 255))
    d.text((W / 2, 936), "The collectors take a finger.", font=font(RYE, 38), fill=(242, 100, 92, 255), anchor="ma", stroke_width=5, stroke_fill=(20, 6, 28, 255))
    return over(base, lay)


def vignette(base):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((x - W / 2) / (W * 0.72)) ** 2 + ((y - H / 2) / (H * 0.72)) ** 2)
    a = np.clip((d - 0.55) / 0.6, 0, 1) ** 1.5 * 200
    v = Image.new("RGBA", (W, H), (4, 1, 8, 0))
    v.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
    return over(base, v)


def main():
    img = background()
    img = over(img, spotlight())
    img = over(img, felt())
    for cx in (130, 215, 300):
        img = over(img, candle(cx, 90 + rng.randint(-12, 12)))
    for cx in (960, 1045, 1130):
        img = over(img, candle(cx, 90 + rng.randint(-12, 12)))
    img = place(img, card(300, 430, "A", "\u2660", False), (470, 640), -17)
    img = place(img, card(300, 430, "K", "\u2665", True), (655, 635), 8)
    img = chip_stack(img, "100_Dollar_casino_chip_1.png", 175, 880, 6, 240)
    img = chip_stack(img, "500_Dollar_casino_chip_1.png", 1010, 870, 4, 240)
    img = chip_stack(img, "25_Dollar_casino_chip_1.png", 1130, 925, 2, 190)
    img = title(img)
    img = vignette(img)
    out = img.convert("RGB")
    out.save(os.path.join(OUT, "cover_1260x1000.png"), optimize=True)
    out.resize((630, 500), Image.LANCZOS).save(os.path.join(OUT, "cover_630x500.png"), optimize=True)


if __name__ == "__main__":
    main()
