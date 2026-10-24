#!/usr/bin/env python3
"""Paints the players' gloves: worn oxblood leather, gold stitches along the seams, a gold spade
on the back of the hand. The texture is drawn in the hands' own UV layout (read from the meshes by
tools/dump_hand_uv.gd), so it fits whatever the layout is. Writes assets/textures/glove_l.png and glove_r.png.
Run: python3 tools/generate_gloves.py  (needs numpy and pillow)"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
LEATHER = np.array([34, 18, 20], dtype=np.float32)
GOLD = (222, 168, 70)
DARK = (14, 8, 12)

def components(d):
    parent = list(range(len(d["uv"])))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    idx = d["idx"]
    for t in range(0, len(idx), 3):
        a, b, c = idx[t:t + 3]
        parent[find(b)] = find(a)
        parent[find(c)] = find(a)
    groups = {}
    for t in range(0, len(idx), 3):
        groups.setdefault(find(idx[t]), []).append(t)
    return sorted(groups.values(), key=len, reverse=True)

def rasterize(d, tris, attr=None):
    """A mask of the triangles in UV space; with `attr` (a per-vertex value) a flat value per triangle."""
    img = Image.new("F" if attr else "L", (S, S), 0)
    dr = ImageDraw.Draw(img)
    idx = d["idx"]
    for t in tris:
        ids = idx[t:t + 3]
        pts = [(d["uv"][k][0] * S, d["uv"][k][1] * S) for k in ids]
        dr.polygon(pts, fill=(sum(attr[k] for k in ids) / 3.0) if attr else 255)
    return img

def noise(seed, blur):
    rng = np.random.default_rng(seed)
    img = Image.fromarray((rng.random((S, S)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(img, dtype=np.float32)
    return (a - a.min()) / (a.max() - a.min())

def spade(draw, cx, cy, size, up, fill):
    """A spade whose point goes along `up` (a unit vector in image space)."""
    ux, uy = up
    pts = []
    for i in range(0, 360, 6):
        t = math.radians(i)
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        # a heart turned over is a spade: its point goes to the local +y
        x, y = x / 17.0 * size, -y / 17.0 * size
        pts.append((cx - x * uy + y * ux, cy + x * ux + y * uy))
    draw.polygon(pts, fill=fill)
    bx, by = cx - ux * size * 0.7, cy - uy * size * 0.7
    sx, sy = cx - ux * size * 1.25, cy - uy * size * 1.25
    wx, wy = -uy * size * 0.28, ux * size * 0.28
    draw.polygon([(bx + wx * 0.2, by + wy * 0.2), (bx - wx * 0.2, by - wy * 0.2), (sx - wx, sy - wy), (sx + wx, sy + wy)], fill=fill)

def paint(side):
    d = json.load(open("/tmp/hand_uv_%s.json" % side))
    tris = list(range(0, len(d["idx"]), 3))
    z = [v[2] for v in d["v"]]
    zmin, zmax = min(z), max(z)
    # the palm faces +x in the hand scene: the back of the hand is every triangle that faces the other way
    back_tris = [t for t in tris if sum(d["n"][k][0] for k in d["idx"][t:t + 3]) / 3 < -0.35]
    zmap = np.asarray(rasterize(d, tris, z))
    mask = np.asarray(rasterize(d, tris)) > 0

    # worn leather: pebbled grain, big dark and light patches, a little red in the creases
    grain = noise(1, 1.2) * 0.6 + noise(2, 3.0) * 0.4
    patches = noise(3, 40)
    base = LEATHER[None, None, :] * (0.7 + 0.8 * grain[..., None]) * (0.75 + 0.5 * patches[..., None])
    scuff = np.clip((noise(4, 6) - 0.62) * 5.0, 0, 1)[..., None]
    base = base + scuff * np.array([40, 26, 22], dtype=np.float32)
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))

    # stitches: a dashed gold line a little inside every seam
    m = Image.fromarray(mask.astype(np.uint8) * 255)
    inner1 = m.filter(ImageFilter.MinFilter(13))
    inner2 = m.filter(ImageFilter.MinFilter(17))
    ring = np.asarray(inner1, dtype=np.int16) - np.asarray(inner2, dtype=np.int16) > 0
    yy, xx = np.mgrid[0:S, 0:S]
    dashes = ((xx // 7 + yy // 7) % 2 == 0)
    stitch = Image.fromarray((ring & dashes).astype(np.uint8) * 255)
    img.paste(Image.new("RGB", (S, S), (190, 140, 60)), mask=stitch)

    img = img.filter(ImageFilter.GaussianBlur(0.6))
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, "glove_%s.png" % side.lower()))

if __name__ == "__main__":
    for s in ("L", "R"):
        paint(s)
