#!/usr/bin/env python3
# Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
# Added 24 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
#
# Writes 4bc Wallet's own loading animation as a Lottie file. The file is
# written by this script and by no drawing program, so every number in it can
# be read here.
#
# The drawing is the "c" of the 4bc sign: an open silver ring whose leading
# part is a yellow light. Two motions can be written:
#
#   ring   the open ring turns without a stop; the light runs ahead and the
#          silver line follows it, stretching to the sign's full "c" and
#          gathering again behind the light
#   sign   the whole sign is written by one line (the 4 and the b, then the
#          c), the light comes on at the end of the c, and the line runs
#          on out of the picture from its beginning
#
# A third word makes no animation of ours: it copies upstream's animation of
# the "Sending transaction" dialog (a turning circle, then a green tick) and
# gives its two near-black turning circles our silver, because near-black
# cannot be seen on this edition's dark dialog. Nothing else in it changes.
#
# A fourth word makes no animation of ours either: it copies upstream's
# animation of the Tor settings screen (an onion with a plug, in purple and
# mint) and gives each of its plain colours one of this edition's: the onion
# silver, its lines near-black, the lights our yellow, the white floor a dark
# shadow. The drawing, the motion and the red of "failed" stay upstream's.
#
# Only what the app's Lottie player draws for certain is used: paths, round
# strokes, trim paths, rotation and opacity. A glow is a set of wider, very
# faint strokes under the light, not a blur.
#
# Usage:
#   python3 local/fourbc_wallet/lottie/make_loader.py ring <out.json>
#   python3 local/fourbc_wallet/lottie/make_loader.py sign <out.json>
#   python3 local/fourbc_wallet/lottie/make_loader.py send-dialog <upstream's loader_and_checkmark.json> <out.json>
#   python3 local/fourbc_wallet/lottie/make_loader.py tor-onion <upstream's onion_animation.json> <out.json>
# The configure script (scripts/app_config/configure_fourbc_wallet.sh) runs the first and the third. Until
# 25 Nov 2026 it ran the fourth too; since then the Tor settings screen has an animation of our own
# (make_lantern.py beside this file), and the fourth word is kept for whoever wants the recoloured onion back.

import json
import math
import sys

SILVER = [0xD9 / 255, 0xDA / 255, 0xDC / 255, 1]
YELLOW = [0xFF / 255, 0xC9 / 255, 0x3C / 255, 1]

FR = 60  # frames a second: only the unit of the times below

# Easing handles: a move that starts and ends softly.
SOFT_OUT = {"x": [0.60], "y": [0.0]}
SOFT_IN = {"x": [0.30], "y": [1.0]}
LINEAR_OUT = {"x": [0.0], "y": [0.0]}
LINEAR_IN = {"x": [1.0], "y": [1.0]}


def still(value):
    return {"a": 0, "k": value}


def moving(keys, soft=True):
    """keys: [(frame, value), ...] -> an animated property."""
    out = []
    for i, (t, v) in enumerate(keys):
        k = {"t": t, "s": v if isinstance(v, list) else [v]}
        if i < len(keys) - 1:
            k["o"] = SOFT_OUT if soft else LINEAR_OUT
            k["i"] = SOFT_IN if soft else LINEAR_IN
        out.append(k)
    return {"a": 1, "k": out}


def transform(rotation=None, opacity=None, at=(0, 0)):
    return {
        "o": opacity or still(100),
        "r": rotation or still(0),
        "p": still([at[0], at[1], 0]),
        "a": still([0, 0, 0]),
        "s": still([100, 100, 100]),
    }


def stroke(colour, width, opacity=100):
    return {
        "ty": "st", "nm": "line",
        "c": still(colour), "o": still(opacity), "w": still(width),
        "lc": 2, "lj": 2,  # round ends, round corners
    }


def trim(start, end, offset=None):
    return {"ty": "tm", "nm": "trim", "s": start, "e": end, "o": offset or still(0), "m": 1}


def group(name, items):
    tr = {"ty": "tr", "p": still([0, 0]), "a": still([0, 0]), "s": still([100, 100]),
          "r": still(0), "o": still(100), "sk": still(0), "sa": still(0)}
    return {"ty": "gr", "nm": name, "it": items + [tr]}


def path(points, closed):
    """points: [(vertex, in handle, out handle)], handles relative to the vertex."""
    return {"ty": "sh", "nm": "path", "ks": still({
        "c": closed,
        "v": [list(p[0]) for p in points],
        "i": [list(p[1]) for p in points],
        "o": [list(p[2]) for p in points],
    })}


def arc_points(cx, cy, r, a0, a1):
    """A circular arc from angle a0 to a1 (degrees, clockwise on the screen,
    0 = to the right), as vertices with handles, in steps of at most 90."""
    steps = max(1, math.ceil(abs(a1 - a0) / 90))
    da = math.radians((a1 - a0) / steps)
    h = 4 / 3 * math.tan(da / 4) * r
    pts = []
    for n in range(steps + 1):
        a = math.radians(a0) + n * da
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        tx, ty = -math.sin(a), math.cos(a)  # the direction of travel
        i = (-tx * h, -ty * h) if n > 0 else (0, 0)
        o = (tx * h, ty * h) if n < steps else (0, 0)
        pts.append(((x, y), i, o))
    return pts


def layer(name, index, shapes, frames, rotation=None, opacity=None, at=(0, 0)):
    return {"ddd": 0, "ind": index, "ty": 4, "nm": name, "sr": 1,
            "ks": transform(rotation, opacity, at), "ao": 0, "shapes": shapes,
            "ip": 0, "op": frames, "st": 0, "bm": 0}


def document(name, size, frames, layers):
    return {"v": "5.10.2", "fr": FR, "ip": 0, "op": frames, "w": size, "h": size,
            "nm": name, "ddd": 0, "assets": [], "layers": layers, "markers": []}


# The light: the yellow line itself, and under it nine wider and very faint ones,
# each a little wider than the last, so that their sum fades evenly outwards.
def light(shape, width, start, end, offset=None):
    items = [group("light", [shape, trim(start, end, offset), stroke(YELLOW, width)])]
    for n in range(1, 10):
        items.append(group("glow", [
            shape, trim(start, end, offset), stroke(YELLOW, width * (1 + 0.24 * n), 4.5),
        ]))
    return items


def ring():
    size, frames = 240, 96           # 1.6 seconds a round
    r, width = 54, 13
    head = 72.0                      # the light's length, in degrees: the sign's own
    short, long = 84.0, 280.0        # the line gathered, and stretched to the sign's "c"
    half = frames // 2
    # The whole circle, starting at the top and going clockwise. It is closed:
    # the handle that arrives at the last point belongs to the first.
    pts = arc_points(0, 0, r, -90, 270)
    first, last = pts[0], pts[-1]
    pts[0] = (first[0], last[1], first[2])
    circle = path(pts[:-1], True)

    def pct(deg):
        return deg / 360 * 100

    # First the light runs ahead and the line stretches; then the tail follows.
    tail = moving([(0, 0.0), (half, 0.0), (frames, pct(long - short))])
    front = moving([(0, pct(short)), (half, pct(long)), (frames, pct(long))])
    light_tail = moving([(0, pct(short - head)), (half, pct(long - head)), (frames, pct(long - head))])
    # The stretch carries the line (long - short) degrees a round; a steady turn adds the rest of 360.
    turn = moving([(0, 0.0), (frames, 360.0 - (long - short))], soft=False)

    shapes = light(circle, width, light_tail, front) + [
        group("silver", [circle, trim(tail, front), stroke(SILVER, width)]),
    ]
    return document("4bc loader: the ring", size, frames, [
        layer("ring", 1, shapes, frames, rotation=turn, at=(size / 2, size / 2)),
    ])


def sign():
    # The sign's small cut (512 by 512), drawn here a little lighter than at
    # 28 points, in a frame with room for the light's glow.
    size, frames = 600, 168          # 2.8 seconds a round
    width = 40
    dx, dy = 44, 62                  # the sign's place in the frame

    def moved(points):
        return [((p[0][0] + dx, p[0][1] + dy), p[1], p[2]) for p in points]

    # The 4 and the b: down the stem, round the bowl, back along the bar, up the slope.
    bowl = arc_points(212, 363, 68, 180, -90)   # left, bottom, right, top
    four_b = moved([((144, 81), (0, 0), (0, 0))] + bowl + [((28, 295), (0, 0), (0, 0))])
    # The c, from its lower end round to its upper end; its last 72 degrees are the light.
    c_all = moved(arc_points(432, 363, 68, 40, 320))
    c_light = moved(arc_points(432, 363, 68, 248, 320))

    line_in = (0, 62)      # the 4 and the b are written
    c_in = (50, 92)        # then the c
    light_in = (86, 104)   # the light comes on
    out = (128, 160)       # and the line runs on out, from its beginning

    def written(span):
        return moving([(0, 0.0), (span[0], 0.0), (span[1], 100.0), (frames, 100.0)])

    def leaving():
        return moving([(0, 0.0), (out[0], 0.0), (out[1], 100.0), (frames, 100.0)])

    glow = moving([(0, 0.0), (light_in[0], 0.0), (light_in[1], 100.0), (out[0], 100.0),
                   (out[0] + 16, 0.0), (frames, 0.0)])

    # A line of no length is still drawn as a dot by its round ends: each line's
    # layer is therefore shown only from the moment its writing begins until it has left.
    def shown(first):
        return moving([(0, 0.0), (first, 0.0), (first + 1, 100.0), (out[1] - 1, 100.0),
                       (out[1], 0.0), (frames, 0.0)], soft=False)

    four_b_line = [group("4 and b", [path(four_b, True), trim(leaving(), written(line_in)), stroke(SILVER, width)])]
    c_line = [group("c", [path(c_all, False), trim(leaving(), written(c_in)), stroke(SILVER, width)])]
    return document("4bc loader: the sign", size, frames, [
        layer("light", 1, light(path(c_light, False), width, still(0), still(100)), frames, opacity=glow),
        layer("c", 2, c_line, frames, opacity=shown(c_in[0])),
        layer("4 and b", 3, four_b_line, frames, opacity=shown(1)),
    ])


def send_dialog(source):
    with open(source) as f:
        doc = json.load(f)
    changed = 0

    def walk(node):
        nonlocal changed
        if isinstance(node, dict):
            colour = node.get("c", {}).get("k") if node.get("ty") == "st" else None
            if isinstance(colour, list) and colour and not isinstance(colour[0], dict) and max(colour[:3]) < 0.2:
                node["c"]["k"] = SILVER
                changed += 1
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(doc)
    if changed == 0:
        sys.exit(f"make_loader: no near-black line found in {source}: upstream's animation has changed, look at it")
    return doc


# Upstream's colours in the Tor onion, and ours in their place.
ONION_COLOURS = {
    "#4B4A8F": "#1F2023",  # outlines and eyes: dark purple to near-black
    "#927AD6": "#D9DADC",  # the onion, its hands and legs: purple to silver
    "#8CE6CD": "#F4F4F5",  # the three feathers and a globe: mint to pale silver
    "#C4C4C4": "#9DA0A6",  # plug and socket: grey to a grey of our ramp
    "#EBEBEB": "#222327",  # the floor: a white plate to a dark shadow
    "#F6E6A8": "#FFE39A",  # plug and socket: pale yellow to a tint of ours
    "#FFE06A": "#FFC93C",  # the lights: yellow to our yellow
    "#FF8383": "#FF8383",  # "failed": red keeps its meaning
}


def tor_onion(source):
    with open(source) as f:
        doc = json.load(f)
    seen = set()

    def walk(node):
        if isinstance(node, dict):
            colour = node.get("c", {}).get("k") if node.get("ty") in ("fl", "st") else None
            if isinstance(colour, list) and colour:
                if isinstance(colour[0], dict):
                    sys.exit(f"make_loader: a colour that changes in time in {source}: upstream's animation has changed, look at it")
                name = "#%02X%02X%02X" % tuple(round(v * 255) for v in colour[:3])
                if name not in ONION_COLOURS:
                    sys.exit(f"make_loader: colour {name} in {source} has no colour of ours: upstream's animation has changed, look at it")
                ours = ONION_COLOURS[name]
                node["c"]["k"] = [int(ours[i:i + 2], 16) / 255 for i in (1, 3, 5)] + list(colour[3:])
                seen.add(name)
            if node.get("ty") in ("gf", "gs"):
                sys.exit(f"make_loader: a gradient in {source}: upstream's animation has changed, look at it")
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(doc)
    missing = sorted(set(ONION_COLOURS) - seen)
    if missing:
        sys.exit(f"make_loader: {', '.join(missing)} not found in {source}: upstream's animation has changed, look at it")
    return doc


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] in ("ring", "sign"):
        doc = ring() if args[0] == "ring" else sign()
    elif len(args) == 3 and args[0] == "send-dialog":
        doc = send_dialog(args[1])
    elif len(args) == 3 and args[0] == "tor-onion":
        doc = tor_onion(args[1])
    else:
        sys.exit("usage: make_loader.py ring|sign <out.json>  |  make_loader.py send-dialog|tor-onion <upstream.json> <out.json>")
    with open(args[-1], "w") as f:
        json.dump(doc, f, separators=(",", ":"))
        f.write("\n")
    print(f"make_loader: wrote {args[-1]} ({doc['w']} by {doc['h']}, {doc['op'] / doc['fr']:.1f} s a round)")


if __name__ == "__main__":
    main()
