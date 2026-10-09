#!/usr/bin/env python3
"""Build the cat avatar from rig.svg and poses.json (see SPEC.md). Needs numpy (the 3D head, model3d.py).

    build.py                     write rig.json and the copies of it and of engine.js (preview.html,
                                 Quickshell's CatEngine.js, Kitty Cam's web/cat/)
    build.py --check             only validate the rig and poses
    build.py --export NAME       print one of the original drawings (poses.json "exports": cat, fat-cat)
                                 as SVG, e.g. build.py --export cat --color '#86d1e8' > cat.svg
    build.py --still EXPR        print an SVG of an expression (reference renderer), e.g.
                                 build.py --still startled --key ear-l.twitch=1 --color '#86d1e8' > out.svg

The exports copy rig.svg's path data verbatim (chained paths joined back into one), so they render
exactly as the hand-drawn originals did. (They used to be written as matugen templates for the kitty
greeting; nothing renders them any more since 2026-10-07.) Without --color they keep matugen's
color tag. rig.json holds every path normalized
to absolute cubic Béziers, so a renderer only needs "move to" and "cubic to".
"""
import argparse
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import model3d

HERE = Path(__file__).resolve().parent
NS = "{http://www.w3.org/2000/svg}"
COLOR_TAG = "{{colors.primary.dark.hex}}"
QML_ENGINE = Path.home() / ".config/quickshell/components/CatEngine.js"
KITTY_CAM = HERE.parent / "kitty-cam/web/cat"  # Kitty Cam (../kitty-cam) bundles its own copy of the cat
SOLID_ATTRS = ("depth", "lift", "billboard", "sweep")  # the 3D head's attributes (SPEC.md)
KAPPA = 0.5522847498  # control-point distance for a quarter ellipse
MARGIN = 4  # around the drawing in rig.json's canvas, beyond half the stroke width
ALIASES = {"eyes": ("eye-l", "eye-r")}  # poses.json shorthand for parts that always change together


# What each class in rig.svg means for a renderer.
CLASSES = {
    "line": {"stroke": True, "fill": False, "alpha": 1, "join": "miter"},
    "line-join": {"stroke": True, "fill": False, "alpha": 1, "join": "round"},
    "ear": {"stroke": True, "fill": False, "alpha": 1, "join": "round"},
    "filled": {"stroke": True, "fill": True, "alpha": 1, "join": "round"},
    "solid": {"stroke": False, "fill": True, "alpha": 1, "join": "round"},
    "blush": {"stroke": False, "fill": True, "alpha": 0.35, "join": "round"},
    "hole": {"stroke": False, "fill": False, "alpha": 1, "join": "round"},
}


class RigError(Exception):
    pass


# ── geometry ──────────────────────────────────────────────────────────────


def path_to_cubic(d):
    """One SVG path (a single subpath) as [P0, C1, C2, P1, C1, C2, P2, ...] in absolute
    coordinates, plus whether it is closed. Lines become cubics with their control points on
    the line, so every segment has the same shape and paths can be blended point by point."""
    toks = re.findall(r"[MmLlHhVvCcSsQqZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", d)
    pts, closed = [], False
    cur = start = (0.0, 0.0)
    prev_c2 = None
    cmd = None
    i = 0

    def num():
        nonlocal i
        v = float(toks[i])
        i += 1
        return v

    def line_to(p):
        a = cur
        pts.extend([(a[0] + (p[0] - a[0]) / 3, a[1] + (p[1] - a[1]) / 3),
                    (a[0] + 2 * (p[0] - a[0]) / 3, a[1] + 2 * (p[1] - a[1]) / 3), p])

    while i < len(toks):
        if re.fullmatch(r"[A-Za-z]", toks[i]):
            cmd = toks[i]
            i += 1
        elif cmd is None:
            raise RigError(f"path starts with a number: {d[:40]}")
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = cur if rel else (0.0, 0.0)
        if c == "M":
            if pts:
                raise RigError(f"one subpath per path, please: {d[:40]}")
            cur = start = (ox + num(), oy + num())
            pts.append(cur)
            cmd = "l" if rel else "L"  # coordinates after a move are line-tos
            prev_c2 = None
        elif c == "Z":
            if math.dist(cur, start) > 1e-6:
                line_to(start)
            closed = True
            cur = start
            prev_c2 = None
        elif c in "LHV":
            if c == "L":
                p = (ox + num(), oy + num())
            elif c == "H":
                p = ((cur[0] if rel else 0) + num(), cur[1])
            else:
                p = (cur[0], (cur[1] if rel else 0) + num())
            line_to(p)
            cur, prev_c2 = p, None
        elif c in "CS":
            if c == "C":
                c1 = (ox + num(), oy + num())
            else:
                c1 = (2 * cur[0] - prev_c2[0], 2 * cur[1] - prev_c2[1]) if prev_c2 else cur
            c2 = (ox + num(), oy + num())
            p = (ox + num(), oy + num())
            pts.extend([c1, c2, p])
            cur, prev_c2 = p, c2
        elif c == "Q":
            q = (ox + num(), oy + num())
            p = (ox + num(), oy + num())
            pts.extend([(cur[0] + 2 / 3 * (q[0] - cur[0]), cur[1] + 2 / 3 * (q[1] - cur[1])),
                        (p[0] + 2 / 3 * (q[0] - p[0]), p[1] + 2 / 3 * (q[1] - p[1])), p])
            cur, prev_c2 = p, None
        else:
            raise RigError(f"unsupported path command {cmd!r}")
    return pts, closed


def ellipse_to_cubic(cx, cy, rx, ry):
    k = KAPPA
    pts = [(cx + rx, cy)]
    for (ax, ay), (bx, by) in [((1, 0), (0, 1)), ((0, 1), (-1, 0)), ((-1, 0), (0, -1)), ((0, -1), (1, 0))]:
        pts += [(cx + rx * (ax + k * bx), cy + ry * (ay + k * by)),
                (cx + rx * (bx + k * ax), cy + ry * (by + k * ay)),
                (cx + rx * bx, cy + ry * by)]
    return pts, True


def to_d(pts, closed):
    f = lambda v: f"{v:.4f}".rstrip("0").rstrip(".")
    out = [f"M {f(pts[0][0])} {f(pts[0][1])}"]
    for j in range(1, len(pts), 3):
        out.append("C " + " ".join(f"{f(x)} {f(y)}" for x, y in pts[j:j + 3]))
    return " ".join(out) + (" Z" if closed else "")


def curve_bounds(pts):
    xs, ys = [pts[0][0]], [pts[0][1]]
    for j in range(1, len(pts), 3):
        p0, c1, c2, p1 = pts[j - 1], pts[j], pts[j + 1], pts[j + 2]
        for s in range(1, 17):
            t = s / 16
            u = 1 - t
            xs.append(u**3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p1[0])
            ys.append(u**3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p1[1])
    return min(xs), min(ys), max(xs), max(ys)


# affine matrices as (a, b, c, d, e, f): x' = a x + c y + e, y' = b x + d y + f
def mul(m, n):
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a * A + c * B, b * A + d * B, a * C + c * D, b * C + d * D, a * E + c * F + e, b * E + d * F + f)


def apply(m, p):
    a, b, c, d, e, f = m
    return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f)


def local_matrix(pivot, t):
    """translate(pivot + t) · rotate(rot°) · scale(sx, sy) · translate(-pivot) — the order SPEC.md fixes."""
    px, py = pivot
    r = math.radians(t.get("rot", 0))
    cos, sin = math.cos(r), math.sin(r)
    m = (1, 0, 0, 1, px + t.get("tx", 0), py + t.get("ty", 0))
    m = mul(m, (cos, sin, -sin, cos, 0, 0))
    m = mul(m, (t.get("sx", 1), 0, 0, t.get("sy", 1), 0, 0))
    return mul(m, (1, 0, 0, 1, -px, -py))


def flap_base(shapes):
    """A flap's (an ear's) base and tip: the first path's endpoints, where it meets the head, and the
    curve point farthest from the line between them."""
    first = shapes[0]["pts"]
    a, b = first[0], first[-1]
    bx, by = b[0] - a[0], b[1] - a[1]
    base_len = math.hypot(bx, by)
    tip, best = None, -1
    for j in range(1, len(first), 3):
        p0, c1, c2, p1 = first[j - 1], first[j], first[j + 1], first[j + 2]
        for n in range(65):
            t = n / 64
            u = 1 - t
            q = (u**3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p1[0],
                 u**3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p1[1])
            dist = abs(bx * (q[1] - a[1]) - by * (q[0] - a[0])) / base_len
            if dist > best:
                tip, best = q, dist
    return a, b, tip


def hinge_key(shapes, rot, scale):
    """A flap swung about its base: the first path's endpoints stay put, its tip (flap_base) turns
    `rot` degrees about their midpoint and moves to `scale` of its distance, and the one affine map
    doing that to those three points moves every path. Shapes in the same form as shapes_of returns
    (only "paths" and "pts" are used)."""
    a, b, tip = flap_base(shapes)
    bx, by = b[0] - a[0], b[1] - a[1]
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    r = math.radians(rot)
    dx, dy = tip[0] - mx, tip[1] - my
    tip2 = (mx + scale * (dx * math.cos(r) - dy * math.sin(r)), my + scale * (dx * math.sin(r) + dy * math.cos(r)))
    # L maps (b - a) to itself and (tip - a) to (tip2 - a): L = [e1 e2'] · [e1 e2]^-1
    e2 = (tip[0] - a[0], tip[1] - a[1])
    f2 = (tip2[0] - a[0], tip2[1] - a[1])
    det = bx * e2[1] - by * e2[0]
    inv = (e2[1] / det, -by / det, -e2[0] / det, bx / det)  # [e1 e2]^-1 as (a, b, c, d), column-major like mul()
    L = mul((bx, by, f2[0], f2[1], 0, 0), (inv[0], inv[1], inv[2], inv[3], 0, 0))
    move = lambda p: (a[0] + L[0] * (p[0] - a[0]) + L[2] * (p[1] - a[1]), a[1] + L[1] * (p[0] - a[0]) + L[3] * (p[1] - a[1]))
    shapes = [{"pts": [move(p) for p in s["paths"][0][0]],
               "paths": [([move(p) for p in pts], closed) for pts, closed in s["paths"]],
               "closed": s["closed"]} for s in shapes]
    # The same map as a matrix [a, b, c, d, e, f] (x' = a x + c y + e): the 3D head bends the ear with it.
    affine = [L[0], L[1], L[2], L[3], a[0] - L[0] * a[0] - L[2] * a[1], a[1] - L[1] * a[0] - L[3] * a[1]]
    return shapes, affine


# ── reading the rig ───────────────────────────────────────────────────────


def read_shape(el):
    tag = el.tag[len(NS):]
    cls = el.get("class", "line")
    if tag == "path":
        pts, closed = path_to_cubic(el.get("d"))
    elif tag == "ellipse":
        pts, closed = ellipse_to_cubic(*(float(el.get(a)) for a in ("cx", "cy", "rx", "ry")))
    else:
        raise RigError(f"unexpected <{tag}>")
    if cls not in CLASSES:
        raise RigError(f"unknown class {cls!r}")
    return {
        "el": el,
        "cls": cls,
        "pts": pts,  # the outline; holes are further subpaths in "paths"
        "closed": closed,
        "paths": [(pts, closed)],
        **CLASSES[cls],
        "chain": el.get("data-chain"),
        "chain_index": int(el.get("data-chain-index", 0)),
    }


def shapes_of(g):
    shapes = []
    for c in g:
        if c.tag not in (NS + "path", NS + "ellipse"):
            continue
        s = read_shape(c)
        if s["cls"] == "hole":
            if not shapes or not shapes[-1]["fill"]:
                raise RigError("a hole must follow a filled shape")
            shapes[-1]["paths"].append((s["pts"], s["closed"]))
            shapes[-1]["evenodd"] = True
        else:
            shapes.append(s)
    return shapes


def read_rig(path):
    root = ET.parse(path).getroot()
    rig = root.find(f"{NS}g[@id='rig']")
    if rig is None:
        raise RigError('rig.svg needs a <g id="rig">')
    m = re.fullmatch(r"translate\(([-\d.]+),\s*([-\d.]+)\)", rig.get("transform", "translate(0,0)"))
    if not m:
        raise RigError("the rig group's transform must be a plain translate(x,y)")
    parts = []

    def walk(g, parent):
        name = g.get("id")
        if not name:
            raise RigError("every part needs an id")
        part = {
            "name": name,
            "parent": parent,
            "pivot": tuple(float(v) for v in g.get("data-pivot").split()),
            "hidden": g.get("display") == "none",
            "variants": {},
            "keys": {},
            "skin": None,
            "key_affines": {},
            "solid": {a: float(g.get("data-" + a)) for a in SOLID_ATTRS if g.get("data-" + a) is not None},
            "el": g,
        }
        if g.get("data-skin"):
            y0, y1 = (float(v) for v in g.get("data-skin-y", "").split())
            part["skin"] = {"bone": g.get("data-skin"), "y": (y0, y1)}
        parts.append(part)
        direct = shapes_of(g)
        children = []
        hinges = {}
        for c in g:
            if c.tag != NS + "g":
                continue
            if c.get("data-variant") is not None:
                part["variants"][c.get("data-variant")] = shapes_of(c)
            elif c.get("data-key") is not None:
                if c.get("data-tip") is not None:
                    rot, scale = (float(v) for v in c.get("data-tip").split())
                    hinges[c.get("data-key")] = (rot, scale)
                else:
                    part["keys"][c.get("data-key")] = shapes_of(c)
            elif c.get("data-pivot") is not None:
                children.append(c)
            else:
                raise RigError(f"{name}: a <g> inside a part must be a part, a variant or a key")
        if direct and part["variants"]:
            raise RigError(f"{name}: either paths or variants, not both")
        if not part["variants"]:
            part["variants"] = {"default": direct}
        for key, (rot, scale) in hinges.items():
            if len(part["variants"]) != 1 or not direct:
                raise RigError(f"{name}.{key}: hinge keys need a part with paths and no variants")
            part["keys"][key], part["key_affines"][key] = hinge_key(direct, rot, scale)
        for key, shapes in part["keys"].items():
            if len(part["variants"]) != 1:
                raise RigError(f"{name}: shape keys only on parts without variants")
            base = part["variants"]["default"]
            if len(shapes) != len(base):
                raise RigError(f"{name}.{key}: {len(shapes)} paths, the part has {len(base)}")
            for n, (s, b) in enumerate(zip(shapes, base)):
                if [(len(q), c) for q, c in s["paths"]] != [(len(q), c) for q, c in b["paths"]]:
                    raise RigError(f"{name}.{key}: path {n} has {len(s['pts'])} points"
                                   f"{' (closed)' if s['closed'] else ''}, the base has {len(b['pts'])}"
                                   f"{' (closed)' if b['closed'] else ''}")
        for c in children:
            walk(c, name)

    for c in rig:
        if c.tag == NS + "g":
            walk(c, None)
    names = [p["name"] for p in parts]
    if len(set(names)) != len(names):
        raise RigError("part ids must be unique")
    for p in parts:
        if p["skin"]:
            if p["skin"]["bone"] not in names or p["parent"] or p["keys"]:
                raise RigError(f"{p['name']}: skin to an existing part, on a top-level part without shape keys")
            if any(q["parent"] == p["name"] for q in parts):
                raise RigError(f"{p['name']}: a skinned part can't have child parts")
    # The 3D head: data-depth on the head, the rest on its own parts.
    for p in parts:
        for attr in p["solid"]:
            if attr == "depth" and p["name"] != "head":
                raise RigError(f"{p['name']}: only the head has a data-depth")
            if attr != "depth" and p["parent"] != "head":
                raise RigError(f"{p['name']}: data-{attr} is for the head's own parts")
    return {
        "viewBox": [float(v) for v in root.get("viewBox").split()],
        "origin": (float(m.group(1)), float(m.group(2))),
        "parts": parts,
    }


def read_poses(path, rig):
    poses = json.loads(Path(path).read_text())
    parts = {p["name"]: p for p in rig["parts"]}

    def expand(pose):  # "eyes" in variants/transforms sets both eye parts
        for field in ("variants", "transforms"):
            entries = pose.get(field, {})
            for alias, names in ALIASES.items():
                if alias in entries:
                    value = entries.pop(alias)
                    for n in names:
                        entries.setdefault(n, value)

    def check(name, pose):
        for part, variant in pose.get("variants", {}).items():
            if part not in parts or variant not in parts[part]["variants"]:
                raise RigError(f"{name}: no variant {part}.{variant}")
        for key in pose.get("keys", {}):
            part, _, k = key.partition(".")
            if part not in parts or k not in parts[part]["keys"]:
                raise RigError(f"{name}: no shape key {key}")
        for part, t in pose.get("transforms", {}).items():
            if part not in parts or set(t) - {"tx", "ty", "sx", "sy", "rot"}:
                raise RigError(f"{name}: bad transform for {part}")
        for part in pose.get("show", []):
            if part not in parts:
                raise RigError(f"{name}: no part {part} to show")

    for name, pose in poses["exports"].items():
        expand(pose)
        check(f"exports.{name}", pose)
    for name, pose in poses["expressions"].items():
        expand(pose)
        check(name, pose)
    if "neutral" not in poses["expressions"]:
        raise RigError("there must be a neutral expression")
    return poses


# ── outputs ───────────────────────────────────────────────────────────────


def visible_shapes(rig, pose):
    """(part, shape) pairs a pose draws, in paint order."""
    for part in rig["parts"]:
        if part["hidden"] and part["name"] not in pose.get("show", []):
            continue
        if any(p["name"] == part["parent"] and p["hidden"] and p["name"] not in pose.get("show", [])
               for p in rig["parts"]):
            continue
        variant = pose.get("variants", {}).get(part["name"], next(iter(part["variants"])))
        for shape in part["variants"][variant]:
            yield part, shape


def build_manifest(rig, poses):
    r = lambda pts: [[round(x, 4), round(y, 4)] for x, y in pts]

    def shape_json(s):
        return {"paths": [{"pts": r(pts), "closed": closed} for pts, closed in s["paths"]],
                "stroke": s["stroke"], "fill": s["fill"], "alpha": s["alpha"], "join": s["join"],
                "evenodd": s.get("evenodd", False), "d": " ".join(to_d(pts, c) for pts, c in s["paths"]),
                **({"chain": s["chain"]} if s["chain"] else {})}

    def skin_weights(part):
        y0, y1 = part["skin"]["y"]

        def w(y):
            u = min(1, max(0, (y1 - y) / (y1 - y0)))
            return round(u * u * (3 - 2 * u), 4)  # smoothstep: 1 at y0 and above, 0 at y1 and below
        return {v: [[[w(y) for _, y in pts] for pts, _ in s["paths"]] for s in shapes]
                for v, shapes in part["variants"].items()}

    # The 3D head (model3d.py): the outline (head and ears, in chain order) inflated to data-depth.
    head = next((p for p in rig["parts"] if p["name"] == "head"), None)
    field = boundary = model = None
    if head and "depth" in head["solid"]:
        outline = sorted(((p, sh) for p in rig["parts"] for sh in p["variants"].get("default", []) if sh["chain"] == "outline"),
                         key=lambda t: t[1]["chain_index"])
        field, boundary, model = model3d.build_head(
            [(p["name"], sh["pts"]) for p, sh in outline], "neck", head["solid"]["depth"])

    def solid_json(part):
        """How a head part sits on the 3D head: lifted above the skin, a billboard (its whole depth: in front of the
        skin anywhere under it, plus its value), or sweeping back beyond the outline (whiskers)."""
        out = {"lift": part["solid"].get("lift", 0.0)}
        if "billboard" in part["solid"]:
            out["billboard"] = round(part["solid"]["billboard"] + max(
                field.at(x, y) for shapes in part["variants"].values() for sh in shapes for pts, _ in sh["paths"] for x, y in pts), 3)
        if "sweep" in part["solid"]:
            out["sweep"] = part["solid"]["sweep"]
        return out

    bounds = [math.inf, math.inf, -math.inf, -math.inf]
    for part in rig["parts"]:
        for shapes in list(part["variants"].values()) + list(part["keys"].values()):
            for s in shapes:
                b = curve_bounds(s["pts"])  # holes lie inside the outline
                bounds = [min(bounds[0], b[0]), min(bounds[1], b[1]), max(bounds[2], b[2]), max(bounds[3], b[3])]
    pad = 1 + MARGIN  # half the stroke, plus room to move
    canvas = [bounds[0] - pad, bounds[1] - pad, bounds[2] - bounds[0] + 2 * pad, bounds[3] - bounds[1] + 2 * pad]

    parts = {}
    for p in rig["parts"]:
        parts[p["name"]] = {
            "parent": p["parent"],
            "pivot": list(p["pivot"]),
            "hidden": p["hidden"],
            "variants": {v: [shape_json(s) for s in shapes] for v, shapes in p["variants"].items()},
            "keys": {k: [[r(pts) for pts, _ in s["paths"]] for s in shapes] for k, shapes in p["keys"].items()},
            "skin": {"bone": p["skin"]["bone"], "weights": skin_weights(p)} if p["skin"] else None,
            "solid": solid_json(p) if field and p["parent"] == "head" else None,
            "keyAffines": {k: [round(v, 6) for v in m] for k, m in p["key_affines"].items()},
        }
    expressions = {}
    for name, e in poses["expressions"].items():
        expressions[name] = {
            "variants": {p["name"]: e.get("variants", {}).get(p["name"], next(iter(p["variants"])))
                         for p in rig["parts"] if len(p["variants"]) > 1},
            "keys": e.get("keys", {}),
            "transforms": e.get("transforms", {}),
            "show": e.get("show", []),
            "motion": e.get("motion"),
            "breath": e.get("breath", 4),
            "sing": bool(e.get("sing")),
        }
    return {
        "version": 1,
        "generated": "by build.py from rig.svg and poses.json - do not edit",
        "viewBox": rig["viewBox"],
        "origin": list(rig["origin"]),
        "canvas": [round(v, 3) for v in canvas],
        "stroke": {"width": 2, "cap": "round"},
        "order": [p["name"] for p in rig["parts"]],
        "parts": parts,
        "expressions": expressions,
        "model": model,
    }


EXPORT_STYLE = """  <style>
    .stroke {
      stroke: %(c)s;
      stroke-width: 2;
      stroke-linecap: round;
      stroke-dasharray: none;
      stroke-opacity: 1;
    }
    .line {
      fill: none;
    }
    .line-join {
      fill: none;
      stroke-linejoin: round;
    }
    .filled {
      fill: %(c)s;
      fill-opacity: 1;
    }
    .ear {
      display: inline;
      fill: none;
      stroke-linejoin: round;
    }
  </style>
""" % {"c": COLOR_TAG}


def export_svg(rig, pose, name):
    vb = rig["viewBox"]
    lines = [
        "<!-- Exported by ~/.config/cat/build.py from rig.svg (pose \"%s\"). -->" % name,
        "<svg",
        '  width="100mm"',
        '  height="100mm"',
        '  viewBox="%s"' % " ".join(f"{v:g}" for v in vb),
        '  xmlns="http://www.w3.org/2000/svg"',
        ">",
        EXPORT_STYLE.rstrip("\n"),
        '  <g transform="translate(%g,%g)">' % rig["origin"],
    ]
    chains = {}
    for _, s in visible_shapes(rig, pose):
        if s["chain"]:
            chains.setdefault(s["chain"], []).append(s)
            if len(chains[s["chain"]]) > 1:
                continue
            lines.append(("chain", s["chain"]))
        else:
            lines.append(element(s, s["el"].get("d")))
    for i, line in enumerate(lines):
        if isinstance(line, tuple):
            segs = sorted(chains[line[1]], key=lambda s: s["chain_index"])
            d = segs[0]["el"].get("d").strip()
            for a, b in zip(segs, segs[1:]):
                end, begin = a["pts"][-1], b["pts"][0]
                if math.dist(end, begin) > 1e-3:
                    raise RigError(f"chain {line[1]}: segment {b['chain_index']} doesn't start where {a['chain_index']} ends")
                rest = re.sub(r"^\s*M\s*[-\d.e]+[ ,]+[-\d.e]+\s*", "", b["el"].get("d"))
                if not re.match(r"[CcLlHhVvSsQq]", rest):
                    raise RigError(f"chain {line[1]}: segment {b['chain_index']} must start 'M x,y' then a drawing command")
                rest = rest.strip()
                if rest[0] == re.findall(r"[A-Za-z]", d)[-1]:
                    rest = rest[1:].lstrip()  # the same command continues: leave the letter implicit
                d += " " + rest
            lines[i] = element(segs[0], d)
    lines += ["  </g>", "</svg>", ""]
    return "\n".join(lines)


def element(s, d):
    el = s["el"]
    cls = el.get("class", "line") + " stroke"
    if el.tag == NS + "ellipse":
        return '    <ellipse class="%s" cx="%s" cy="%s" rx="%s" ry="%s" />' % (
            cls, el.get("cx"), el.get("cy"), el.get("rx"), el.get("ry"))
    return '    <path class="%s" d="%s" />' % (cls, d)


def still_svg(rig, manifest, expr, extra_keys, color):
    """Reference renderer: one expression, shape keys and transforms applied, as plain SVG."""
    e = manifest["expressions"][expr]
    keys = dict(e["keys"], **extra_keys)
    world = {}
    for p in rig["parts"]:
        m = local_matrix(p["pivot"], e["transforms"].get(p["name"], {}))
        world[p["name"]] = mul(world[p["parent"]], m) if p["parent"] else m
    pose = {"variants": e["variants"], "show": e["show"]}
    out = []
    for part, s in visible_shapes(rig, pose):
        paths = [list(pts) for pts, _ in s["paths"]]
        idx = next((i for i, b in enumerate(part["variants"].get("default", [])) if b is s), None)
        if idx is not None:
            for k, shapes in part["keys"].items():
                w = keys.get(f"{part['name']}.{k}", 0)
                paths = [[(x + w * (kx - bx), y + w * (ky - by)) for (x, y), (bx, by), (kx, ky) in zip(cur, base, key)]
                         for cur, (base, _), (key, _) in zip(paths, s["paths"], shapes[idx]["paths"])]
        d = " ".join(to_d([apply(world[part["name"]], p) for p in pts], c) for pts, (_, c) in zip(paths, s["paths"]))
        out.append('  <path d="%s" fill="%s" fill-opacity="%g" fill-rule="%s" stroke="%s" stroke-linejoin="%s" />' % (
            d, color if s["fill"] else "none", s["alpha"], "evenodd" if s.get("evenodd") else "nonzero",
            color if s["stroke"] else "none", s["join"]))
    x, y, w, h = manifest["canvas"]
    return "\n".join([
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x:g} {y:g} {w:g} {h:g}" width="{w * 4:g}" height="{h * 4:g}">',
        '<g stroke-width="2" stroke-linecap="round">',
        *out, "</g>", "</svg>", ""])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="validate only, write nothing")
    ap.add_argument("--export", metavar="NAME", help="print one of the original drawings")
    ap.add_argument("--still", metavar="EXPR", help="print an SVG of this expression")
    ap.add_argument("--key", action="append", default=[], metavar="PART.KEY=W", help="extra shape-key weight for --still")
    ap.add_argument("--color", help="stroke color for --still (default black) and --export")
    args = ap.parse_args()
    try:
        rig = read_rig(HERE / "rig.svg")
        poses = read_poses(HERE / "poses.json", rig)
        manifest = build_manifest(rig, poses)
        exports = {name: export_svg(rig, pose, name) for name, pose in poses["exports"].items()}
        if args.still:
            if args.still not in manifest["expressions"]:
                raise RigError(f"no expression {args.still}")
            extra = {k: float(w) for k, _, w in (s.partition("=") for s in args.key)}
            sys.stdout.write(still_svg(rig, manifest, args.still, extra, args.color or "#000000"))
            return
        if args.export:
            if args.export not in exports:
                raise RigError(f"no export {args.export} (there are: {', '.join(exports)})")
            svg = exports[args.export]
            sys.stdout.write(svg.replace(COLOR_TAG, args.color) if args.color else svg)
            return
    except RigError as e:
        sys.exit(f"build.py: {e}")
    if args.check:
        print(f"ok: {len(manifest['parts'])} parts, {len(manifest['expressions'])} expressions")
        return
    rig_json = json.dumps(manifest, separators=(",", ":"))
    (HERE / "rig.json").write_text(rig_json + "\n")
    engine = (HERE / "engine.js").read_text()
    page = "preview.html"  # carries its own copies: it works from file://
    html = (HERE / page).read_text()
    for marker, content in (("RIG", rig_json), ("ENGINE", "\n" + engine)):
        html, n = re.subn(r"/\*%s\*/.*?/\*END\*/" % marker, lambda _: f"/*{marker}*/{content}/*END*/", html, flags=re.S)
        if n != 1:
            sys.exit(f"build.py: {page} lost its /*{marker}*/…/*END*/ markers")
    (HERE / page).write_text(html)
    QML_ENGINE.write_text("// Generated by ~/.config/cat/build.py from ~/.config/cat/engine.js; edit that, not this.\n" + engine)
    wrote = ["rig.json", "preview.html", "CatEngine.js"]
    if KITTY_CAM.parent.is_dir():
        KITTY_CAM.mkdir(exist_ok=True)
        (KITTY_CAM / "rig.json").write_text(rig_json + "\n")
        (KITTY_CAM / "engine.js").write_text("// Published by ~/.config/cat/build.py from ~/.config/cat/engine.js; edit that, not this.\n" + engine)
        wrote.append("kitty-cam/web/cat/")
    print("wrote " + ", ".join(wrote))


if __name__ == "__main__":
    main()
