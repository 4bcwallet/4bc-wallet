#!/usr/bin/env python3
# Local tool of the 4bc Wallet project (not part of upstream Stack Wallet).
# Added 25 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
#
# Writes 4bc Wallet's own animation for the Tor settings screen as a Lottie
# file: this edition's hooded figure carries a lantern, and the lantern is the
# connection. Dark at rest; a small light circles inside the glass while the
# app connects; lit, with a soft breathing heart of light, when connected; a
# short red flicker for "failed".
#
# The figure is a drawn picture, in two states that lie beside this script:
# lantern-dark.png and lantern-lit.png (540 pixels square; the second is the
# first with the glass given our yellow). They are put inside the file, the
# lit one fading in over the dark one. The light is written here, by this
# script and by no drawing program: the circling light, the halo, the heart,
# the red flicker. Only what the app's Lottie player draws for certain is
# used: pictures, paths, round strokes, fills, trim paths, rotation, opacity.
#
# The screen plays the file between eight markers, so the file keeps their
# names and frames, and its size, frame rate and length (180 by 180, 25 frames
# a second, 436 frames):
#   frame 0                  at rest, not connected
#   0 to 75                  once, at the tap
#   75 to 165                again and again while connecting (165 looks as 75)
#   on to 255                once, when the connection stands
#   255 to 290               again and again while connected (290 looks as 255)
#   297 to 341               once, at the disconnect (341 looks as 0)
#   378 to 433               "failed"
#
# Usage:
#   python3 local/fourbc_wallet/lottie/make_lantern.py <out.json>
# The configure script (scripts/app_config/configure_fourbc_wallet.sh) runs it.

import base64
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PX = 540                      # the two pictures' side, in pixels
K = 180 / 560                 # the pictures show 560 of the drawing's pixels across the animation's 180 units
GX, GY, GR = 280 * K, 383 * K, 84 * K   # the lantern's glass in those units: its middle and its radius

# ---- the Lottie file ----
YELLOW, PALE, RED = [1, 0xC9 / 255, 0x3C / 255, 1], [1, 0xEC / 255, 0xA8 / 255, 1], [0xD3 / 255, 0x4E / 255, 0x50 / 255, 1]
SOFT = {"o": {"x": [0.45], "y": [0]}, "i": {"x": [0.4], "y": [1]}}
LINE = {"o": {"x": [0], "y": [0]}, "i": {"x": [1], "y": [1]}}

def still(v):
    return {"a": 0, "k": v}

def keys(pairs, ease=SOFT):
    out = []
    for n, (t, v) in enumerate(pairs):
        k = {"t": t, "s": v if isinstance(v, list) else [v]}
        if n < len(pairs) - 1:
            k.update(ease)
        out.append(k)
    return {"a": 1, "k": out}

def ks(opacity=100, rotation=0, position=None, anchor=(0, 0), scale=100):
    return {"o": opacity if isinstance(opacity, dict) else still(opacity),
            "r": rotation if isinstance(rotation, dict) else still(rotation),
            "p": position if isinstance(position, dict) else still(list(position or anchor) + [0]),
            "a": still(list(anchor) + [0]), "s": still([scale, scale, 100])}

def circle(r):
    c = 0.5523 * r
    return {"ty": "sh", "ks": still({"c": True, "v": [[0, -r], [r, 0], [0, r], [-r, 0]],
                                    "i": [[-c, 0], [0, -c], [c, 0], [0, c]], "o": [[c, 0], [0, c], [-c, 0], [0, -c]]})}

def group(items, name):
    return {"ty": "gr", "nm": name, "it": items + [{"ty": "tr", "p": still([0, 0]), "a": still([0, 0]), "s": still([100, 100]),
                                                    "r": still(0), "o": still(100)}]}

def stroke(colour, width, opacity=100):
    return {"ty": "st", "c": still(colour), "o": still(opacity), "w": still(width), "lc": 2, "lj": 2}

def trim(start, end):
    return {"ty": "tm", "s": still(start), "e": still(end), "o": still(0), "m": 1}

def shape_layer(name, ind, shapes, **k):
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1, "ks": ks(**k), "ao": 0, "shapes": shapes, "ip": 0, "op": 436, "st": 0, "bm": 0}

def image_layer(name, ind, ref, **k):
    return {"ddd": 0, "ind": ind, "ty": 2, "nm": name, "refId": ref, "sr": 1, "ks": ks(scale=100 * 180 / PX, **k), "ao": 0, "ip": 0, "op": 436, "st": 0, "bm": 0}

def animation():
    asset = lambda i, name: {"id": i, "w": PX, "h": PX, "u": "", "e": 1,
                             "p": "data:image/png;base64," + base64.b64encode((HERE / name).read_bytes()).decode()}
    # The circling light: a short bright body with a tail that thins and fades, on no drawn track.
    r = GR * 0.60
    snake = [group([circle(r), trim(a, b), stroke(PALE if n == 0 else YELLOW, w, o)], f"part {n}")
             for n, (a, b, w, o) in enumerate([(22, 31, 3.4, 100), (14, 22, 2.6, 70), (7, 14, 1.8, 42), (0, 7, 1.1, 20)])]
    # The halo: nine thin, very faint rings beyond the glass; together they fade evenly.
    halo = [group([circle(GR + 1.5 + n * 2.6), stroke(PALE, 4.2, 13 - n * 1.3)], f"ring {n}") for n in range(9)]
    # The breath of the lit lantern: a soft, nearly white heart in the glass (five faint discs, one inside
    # the other), which swells and sinks. The lit picture itself stays whole: dimming it lets the dark
    # glass through and looks dirty (seen in the second preview).
    WHITE = [1, 0xF8 / 255, 0xE2 / 255, 1]
    heart = [group([circle(GR * f), {"ty": "fl", "c": still(WHITE), "o": still(10), "r": 1}], f"disc {n}")
             for n, f in enumerate((0.78, 0.62, 0.47, 0.33, 0.20))]
    red = [group([circle(GR - 1.2), {"ty": "fl", "c": still(RED), "o": still(100), "r": 1}], "glass")]
    layers = [
        shape_layer("failed", 1, red, anchor=(0, 0), position=(GX, GY),
                    opacity=keys([(0, 0), (378, 0), (388, 55), (398, 12), (408, 42), (433, 0)])),
        shape_layer("light", 2, snake, anchor=(0, 0), position=(GX, GY),
                    rotation=keys([(0, 0), (255, 255 * 8)], LINE),
                    opacity=keys([(0, 0), (8, 0), (40, 100), (165, 100), (215, 0), (436, 0)])),
        shape_layer("halo", 3, halo, anchor=(0, 0), position=(GX, GY),
                    opacity=keys([(0, 0), (185, 0), (255, 100), (272.5, 62), (290, 100), (297, 100), (341, 0), (436, 0)])),
        shape_layer("heart", 6, heart, anchor=(0, 0), position=(GX, GY),
                    opacity=keys([(0, 0), (215, 0), (255, 100), (272.5, 30), (290, 100), (297, 100), (341, 0), (436, 0)])),
        image_layer("lantern lit", 4, "lit",
                    opacity=keys([(0, 0), (8, 0), (40, 24), (165, 24), (255, 100), (297, 100), (341, 0), (436, 0)])),
        image_layer("figure", 5, "dark", anchor=(0, 0),
                    position=keys([(0, [0, 0, 0]), (378, [0, 0, 0]), (384, [-1.6, 0, 0]), (390, [1.6, 0, 0]), (396, [-1, 0, 0]),
                                   (402, [1, 0, 0]), (408, [0, 0, 0]), (436, [0, 0, 0])])),
    ]
    markers = [{"tm": t, "cm": n, "dr": 0} for t, n in (
        (75, "connecting-start"), (165, "connecting-end"), (255, "connected-start"), (290, "connected-end"),
        (297, "disconnection-start"), (341, "disconnection-end"), (378, "failed-start"), (433, "failed-end"))]
    return {"v": "5.10.2", "fr": 25, "ip": 0, "op": 436, "w": 180, "h": 180, "nm": "4bc-wallet-tor-lantern", "ddd": 0,
            "assets": [asset("dark", "lantern-dark.png"), asset("lit", "lantern-lit.png")], "layers": layers, "markers": markers}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: make_lantern.py <out.json>")
    doc = animation()
    with open(sys.argv[1], "w") as f:
        json.dump(doc, f, separators=(",", ":"))
        f.write("\n")
    print(f"make_lantern: wrote {sys.argv[1]} ({doc['w']} by {doc['h']}, {doc['op']} frames, {Path(sys.argv[1]).stat().st_size // 1024} KB)")
