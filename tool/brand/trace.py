import sys, numpy as np
from PIL import Image, ImageFilter
import potrace

src, out = sys.argv[1], sys.argv[2]
SCALE = 4
im = Image.open(src).convert('L')
w, h = im.size
big = im.resize((w * SCALE, h * SCALE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(SCALE * 0.9))
a = np.asarray(big).astype(np.int16)
yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
latin_box = (xx < 625 * SCALE) & (yy > 768 * SCALE) & (yy < 842 * SCALE)
ink = (a < 128) & ~latin_box
sharp = np.asarray(im.resize((w * SCALE, h * SCALE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(SCALE * 0.45))).astype(np.int16)
latin = (sharp < 185) & latin_box

def path_d(mask):
    bm = potrace.Bitmap(~mask)
    plist = bm.trace(turdsize=40 * SCALE, turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY, alphamax=1.0, opticurve=True, opttolerance=0.25)
    s = 1.0 / SCALE
    f = lambda p: f"{p.x * s:.2f} {p.y * s:.2f}"
    parts = []
    for curve in plist:
        parts.append("M" + f(curve.start_point))
        for seg in curve.segments:
            if seg.is_corner:
                parts.append("L" + f(seg.c) + "L" + f(seg.end_point))
            else:
                parts.append("C" + f(seg.c1) + " " + f(seg.c2) + " " + f(seg.end_point))
        parts.append("Z")
    return "".join(parts)

ink_d, latin_d = path_d(ink), path_d(latin)
# tight viewBox around both masks with a small margin
ys, xs = np.nonzero(ink | latin)
m = 6
x0, y0 = xs.min() / SCALE - m, ys.min() / SCALE - m
x1, y1 = xs.max() / SCALE + m, ys.max() / SCALE + m
vb = f"{x0:.1f} {y0:.1f} {x1 - x0:.1f} {y1 - y0:.1f}"
open(out, 'w').write(
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">'
    f'<path id="ink" fill="#000000" fill-rule="evenodd" d="{ink_d}"/>'
    f'<path id="latin" fill="#8A8A8A" fill-rule="evenodd" d="{latin_d}"/>'
    '</svg>\n')
# arabic-only version for icons
ys, xs = np.nonzero(ink)
x0, y0, x1, y1 = xs.min() / SCALE - m, ys.min() / SCALE - m, xs.max() / SCALE + m, ys.max() / SCALE + m
open(out.replace('.svg', '_mark.svg'), 'w').write(
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {x1 - x0:.1f} {y1 - y0:.1f}">'
    f'<path fill="#000000" fill-rule="evenodd" d="{ink_d}"/></svg>\n')
print(vb, len(ink_d), len(latin_d))
