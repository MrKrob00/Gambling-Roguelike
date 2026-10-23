#!/usr/bin/env python3
"""Procedural pixel-art card templates (64x96), palette matched to Dark Dwellers UI.

Usage: python3 tools/generate_cards.py
Writes PNGs to assets/art/cards/. Requires Pillow.
Import in Godot with Filter = Nearest.
"""
import os

from PIL import Image, ImageDraw

W, H = 64, 96
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art", "cards")

NAVY = "#111343"
INK = "#1b1450"
PURPLE_D = "#332370"
PURPLE = "#4e298e"
SLATE = "#4c4682"
SLATE_L = "#6b699b"
MAGENTA = "#a81271"
ORANGE = "#f27646"
GOLD = "#f4a13a"
TEAL = "#7bb6bc"

RARITY = {
    "common": SLATE_L,
    "uncommon": TEAL,
    "rare": MAGENTA,
    "legendary": GOLD,
    "cursed": ORANGE,
}


def blank():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def rounded_mask(im, r=3):
    """Clip the four corners with a small pixel radius."""
    px = im.load()
    for cx, cy in ((0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)):
        for dx in range(r):
            for dy in range(r):
                x = cx + (dx if cx == 0 else -dx)
                y = cy + (dy if cy == 0 else -dy)
                if (r - 1 - dx) ** 2 + (r - 1 - dy) ** 2 > (r - 0.5) ** 2:
                    px[x, y] = (0, 0, 0, 0)


def mirror4(d, pts, color):
    """Draw pixels symmetric about both axes of the card."""
    for x, y in pts:
        for xx, yy in ((x, y), (W - 1 - x, y), (x, H - 1 - y), (W - 1 - x, H - 1 - y)):
            d.point((xx, yy), fill=color)


def eye(d, cx, cy, ring, iris, white="#f3e9d2"):
    """Small all-seeing eye medallion, 17x17."""
    for y in range(-8, 9):
        for x in range(-8, 9):
            r2 = x * x + y * y
            if 49 <= r2 <= 72:
                d.point((cx + x, cy + y), fill=ring)
            elif r2 < 49:
                d.point((cx + x, cy + y), fill=NAVY)
    # almond-shaped eye
    for x in range(-6, 7):
        h = int(round(3.2 * (1 - (x / 6.5) ** 2)))
        for y in range(-h, h + 1):
            d.point((cx + x, cy + y), fill=white)
    for y in range(-3, 4):
        for x in range(-3, 4):
            if x * x + y * y <= 9:
                d.point((cx + x, cy + y), fill=iris)
    d.point((cx, cy), fill=NAVY)
    d.point((cx - 1, cy - 1), fill=white)


def card_back(main, accent, name):
    im, d = blank()
    d.rectangle((0, 0, W - 1, H - 1), fill=NAVY)
    d.rectangle((1, 1, W - 2, H - 2), fill=accent)
    d.rectangle((2, 2, W - 3, H - 3), fill=NAVY)
    d.rectangle((3, 3, W - 4, H - 4), fill=main)
    # diamond lattice
    for y in range(4, H - 4):
        for x in range(4, W - 4):
            if (x + y) % 8 == 0 or (x - y) % 8 == 0:
                d.point((x, y), fill=PURPLE if main == PURPLE_D else PURPLE_D)
    # inner gold frame
    d.rectangle((7, 7, W - 8, H - 8), outline=accent)
    d.rectangle((9, 9, W - 10, H - 10), outline=NAVY)
    # clear field behind medallion
    d.rectangle((10, 10, W - 11, H - 11), fill=main)
    for y in range(10, H - 10):
        for x in range(10, W - 10):
            if (x + y) % 6 == 0 and (x - y) % 6 == 0:
                d.point((x, y), fill=accent)
    # centre medallion
    cx, cy = W // 2, H // 2
    d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=NAVY, outline=accent)
    d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), outline=main)
    eye(d, cx, cy, accent, MAGENTA if accent == GOLD else GOLD)
    # radiating ticks around medallion
    for i in range(12):
        import math
        a = i * math.pi / 6
        x1, y1 = cx + 17 * math.cos(a), cy + 17 * math.sin(a)
        x2, y2 = cx + 20 * math.cos(a), cy + 20 * math.sin(a)
        d.line((x1, y1, x2, y2), fill=accent)
    # corner ornaments
    mirror4(d, [(12, 12), (13, 13), (11, 13), (13, 11), (12, 14), (12, 10), (14, 12), (10, 12)], accent)
    mirror4(d, [(20, 12), (12, 20), (22, 12), (12, 22)], accent)
    rounded_mask(im)
    im.save(os.path.join(OUT, name))


def card_front(color, name):
    im, d = blank()
    d.rectangle((0, 0, W - 1, H - 1), fill=NAVY)
    d.rectangle((1, 1, W - 2, H - 2), fill=color)
    d.rectangle((2, 2, W - 3, H - 3), fill=NAVY)
    d.rectangle((3, 3, W - 4, H - 4), fill=INK)
    # art window
    d.rectangle((6, 6, W - 7, 50), fill=NAVY)
    d.rectangle((7, 7, W - 8, 49), fill=PURPLE_D)
    d.rectangle((6, 6, W - 7, 50), outline=color)
    for x in range(7, W - 7):  # subtle vignette lines
        d.point((x, 8), fill=SLATE if color != SLATE_L else PURPLE)
    # name plate
    d.rectangle((6, 54, W - 7, 64), fill=NAVY, outline=color)
    d.rectangle((8, 56, W - 9, 62), fill=PURPLE_D)
    # text box with faint lines
    d.rectangle((6, 68, W - 7, H - 8), fill=NAVY, outline=SLATE)
    for y in (73, 78, 83):
        d.line((9, y, W - 10, y), fill=PURPLE_D)
    # corner gems
    mirror4(d, [(5, 5), (6, 5), (5, 6)], color)
    rounded_mask(im)
    im.save(os.path.join(OUT, name))


def card_slot(name="card_slot.png"):
    """Empty slot outline drawn where a card can be placed."""
    im, d = blank()
    d.rectangle((0, 0, W - 1, H - 1), outline=SLATE)
    d.rectangle((2, 2, W - 3, H - 3), outline=PURPLE_D)
    for x in range(6, W - 6, 4):
        d.point((x, 5), fill=SLATE)
        d.point((x, H - 6), fill=SLATE)
    rounded_mask(im)
    im.save(os.path.join(OUT, name))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    card_back(PURPLE_D, GOLD, "card_back_purple.png")
    card_back("#5a0f45", GOLD, "card_back_crimson.png")
    for rarity, color in RARITY.items():
        card_front(color, f"card_front_{rarity}.png")
    card_slot()
    print("wrote", len(os.listdir(OUT)), "files to", os.path.relpath(OUT))
