import sys, numpy as np
from PIL import Image, ImageFilter
import potrace
src, out = sys.argv[1], sys.argv[2]
SCALE = 8
im = Image.open(src).convert('RGB').crop((392, 405, 690, 680))
w, h = im.size
big = im.resize((w * SCALE, h * SCALE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(SCALE * 0.7))
a = np.asarray(big).astype(np.int16)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
teal = ((g - r) > 45) & ((b - r) > 35)
gold = ((r - b) > 28) & ((g - b) > 18) & (r > 120)

def path_d(mask):
    plist = potrace.Bitmap(~mask).trace(turdsize=30 * SCALE, turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY, alphamax=1.0, opticurve=True, opttolerance=0.3)
    s = 1.0 / SCALE
    f = lambda p: f"{p.x * s:.2f} {p.y * s:.2f}"
    parts = []
    for curve in plist:
        parts.append("M" + f(curve.start_point))
        for seg in curve.segments:
            parts.append(("L" + f(seg.c) + "L" + f(seg.end_point)) if seg.is_corner else ("C" + f(seg.c1) + " " + f(seg.c2) + " " + f(seg.end_point)))
        parts.append("Z")
    return "".join(parts)

ys, xs = np.nonzero(teal | gold)
m = 3
x0, y0, x1, y1 = xs.min() / SCALE - m, ys.min() / SCALE - m, xs.max() / SCALE + m, ys.max() / SCALE + m
open(out, "w").write(
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {x1 - x0:.1f} {y1 - y0:.1f}">'
    f'<path id="main" fill="#6C5CE7" fill-rule="evenodd" d="{path_d(teal)}"/>'
    f'<path id="lines" fill="#E39A27" fill-rule="evenodd" d="{path_d(gold)}"/></svg>\n')
print(x0, y0, x1 - x0, y1 - y0)
