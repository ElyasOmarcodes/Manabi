"""Builds app/assets/brand/almanabea_lottie.json, the animated المنابع logo,
from the vector paths in app/assets/brand/almanabea.svg.

The calligraphy is drawn in with a stroke (trim path), then filled while the
stroke fades, and the Latin name rises in underneath; the app recolours the
layers per theme. Run: python3 tool/brand/lottie.py [--check]
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
svg = (root / "app/assets/brand/almanabea.svg").read_text()
vx, vy, vw, vh = [float(v) for v in re.search(r'viewBox="([^"]+)"', svg).group(1).split()]
FPS, FRAMES = 60, 168  # 2.8 s


def subpaths(d):
    """Absolute M/L/C/Z path data → list of (vertices, in, out, closed)."""
    tokens = re.findall(r"[MLCZ]|-?\d*\.?\d+", d)
    out, i, cur = [], 0, None
    pt = lambda k: (float(tokens[k]) - vx, float(tokens[k + 1]) - vy)
    while i < len(tokens):
        t = tokens[i]
        if t == "M":
            cur = {"v": [pt(i + 1)], "i": [(0, 0)], "o": [(0, 0)], "c": False}
            out.append(cur)
            i += 3
        elif t == "L":
            cur["v"].append(pt(i + 1)); cur["i"].append((0, 0)); cur["o"].append((0, 0))
            i += 3
        elif t == "C":
            c1, c2, p = pt(i + 1), pt(i + 3), pt(i + 5)
            last = cur["v"][-1]
            cur["o"][-1] = (c1[0] - last[0], c1[1] - last[1])
            cur["v"].append(p); cur["i"].append((c2[0] - p[0], c2[1] - p[1])); cur["o"].append((0, 0))
            i += 7
        elif t == "Z":
            cur["c"] = True
            # A closing point equal to the start is merged into it.
            if len(cur["v"]) > 1 and abs(cur["v"][-1][0] - cur["v"][0][0]) < 0.01 and abs(cur["v"][-1][1] - cur["v"][0][1]) < 0.01:
                cur["i"][0] = cur["i"][-1]
                cur["v"].pop(); cur["i"].pop(); cur["o"].pop()
            i += 1
        else:
            i += 1
    r = lambda pts: [[round(x, 2), round(y, 2)] for x, y in pts]
    return [{"v": r(p["v"]), "i": r(p["i"]), "o": r(p["o"]), "c": p["c"]} for p in out]


def ease(t, v, t2, v2):
    """Keyframes with a smooth ease in and out."""
    return {"a": 1, "k": [
        {"t": t, "s": v if isinstance(v, list) else [v], "o": {"x": [0.65], "y": [0]}, "i": {"x": [0.35], "y": [1]}},
        {"t": t2, "s": v2 if isinstance(v2, list) else [v2]},
    ]}


def keys(*frames):
    """Multi-keyframe value: keys((t, v), (t, v), ...)."""
    out = []
    for n, (t, v) in enumerate(frames):
        k = {"t": t, "s": v if isinstance(v, list) else [v]}
        if n < len(frames) - 1:
            k["o"] = {"x": [0.6], "y": [0]}
            k["i"] = {"x": [0.3], "y": [1]}
        out.append(k)
    return {"a": 1, "k": out}


static = lambda v: {"a": 0, "k": v}


def layer(name, ind, paths, *, color, draw, fill_in, stroke_out, rise=None, width=7):
    shapes = [{"ty": "sh", "nm": f"{name}-{n}", "ks": static(p)} for n, p in enumerate(paths)]
    shapes += [
        {"ty": "tm", "nm": "draw", "s": static(0), "e": ease(draw[0], 0, draw[1], 100), "o": static(0), "m": 1},
        {"ty": "st", "nm": "stroke", "c": static(color + [1]), "o": keys((0, 100), (stroke_out[0], 100), (stroke_out[1], 0)), "w": static(width), "lc": 2, "lj": 2},
        {"ty": "fl", "nm": "fill", "c": static(color + [1]), "o": ease(fill_in[0], 0, fill_in[1], 100), "r": 2},
        {"ty": "tr", "p": static([0, 0]), "a": static([0, 0]), "s": static([100, 100]), "r": static(0), "o": static(100)},
    ]
    position = static([0, 0, 0]) if rise is None else ease(rise[0], [0, 14, 0], rise[1], [0, 0, 0])
    opacity = static(100) if rise is None else ease(rise[0], 0, rise[1], 100)
    return {
        "ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1, "ip": 0, "op": FRAMES, "st": 0, "bm": 0,
        "ks": {"o": opacity, "r": static(0), "p": position, "a": static([0, 0, 0]), "s": static([100, 100, 100])},
        "shapes": [{"ty": "gr", "nm": name, "it": shapes}],
    }


ink = subpaths(re.search(r'id="ink"[^>]* d="([^"]+)"', svg).group(1))
latin = subpaths(re.search(r'id="latin"[^>]* d="([^"]+)"', svg).group(1))
violet = [0x6C / 255, 0x5C / 255, 0xE7 / 255]
grey = [0x8A / 255] * 3
doc = {
    "v": "5.9.0", "fr": FPS, "ip": 0, "op": FRAMES, "w": round(vw), "h": round(vh), "nm": "almanabea", "ddd": 0, "assets": [],
    # Layer names are what the app recolours: "ink" and "latin".
    "layers": [
        layer("ink", 1, ink, color=violet, draw=(0, 78), fill_in=(52, 100), stroke_out=(92, 116)),
        layer("latin", 2, latin, color=grey, draw=(70, 118), fill_in=(96, 128), stroke_out=(118, 136), rise=(70, 120), width=1.2),
    ],
}
text = json.dumps(doc, separators=(",", ":"))
target = root / "app/assets/brand/almanabea_lottie.json"
if "--check" in sys.argv:
    sys.exit(0 if target.exists() and target.read_text() == text else "almanabea_lottie.json is out of date")
target.write_text(text)
print(f"wrote {target.relative_to(root)}: {len(text) // 1024} KB, {len(ink)} + {len(latin)} paths")
