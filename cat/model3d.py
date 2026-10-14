"""The cat's head as a real 3D object, inflated from the drawing (SPEC.md, "The 3D head").

The head's outline (with the ears, closed across the neck) is puffed up into a rounded solid: the height over
each point is sqrt(h), where h solves the Poisson equation Δh = −4 inside the outline with h = 0 on it. That gives
an exact hemisphere over a disk and a round cross-section everywhere, so narrower parts come out thinner (the ears are
soft lobes, like a plush toy's); it's then scaled to the head's depth. The
solid is symmetric front to back. A triangle mesh of it (front and back sheets meeting at the outline) is what
the engine turns, draws the silhouette of and hides lines behind; every point of the head's drawn parts gets a
depth from the same height field.
"""
import math

import numpy as np

CELL = 0.5  # the height field's grid, rig units
EDGE = 2.0  # spacing of the mesh's vertices along the outline
INNER = 3.5  # spacing of its vertices inside
RINGS = (0.4, 1.2, 2.4)  # rings of vertices this far inside the outline, where the surface is steepest
NECK_BAND = 5.0  # the head's underside within this of the neck draws no silhouette (the body goes on there)


def bezier_samples(pts, per_unit=4):
    """Points along a path of cubic Béziers ([P0, C1, C2, P1, …]), dense enough for `per_unit` per rig unit."""
    out = [tuple(pts[0])]
    for j in range(1, len(pts), 3):
        p0, c1, c2, p1 = pts[j - 1], pts[j], pts[j + 1], pts[j + 2]
        n = max(4, int(math.dist(p0, c1) + math.dist(c1, c2) + math.dist(c2, p1)) * per_unit)
        for k in range(1, n + 1):
            t = k / n
            u = 1 - t
            out.append((u**3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p1[0],
                        u**3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p1[1]))
    return out


def resample(points, tags, spacing):
    """A closed polyline resampled at even spacing, each new point keeping the tag of the stretch it's on."""
    seg = [math.dist(points[i], points[(i + 1) % len(points)]) for i in range(len(points))]
    total = sum(seg)
    n = max(8, round(total / spacing))
    out, out_tags, i, along = [], [], 0, 0.0
    for k in range(n):
        target = k * total / n
        while along + seg[i] < target:
            along += seg[i]
            i += 1
        t = (target - along) / seg[i] if seg[i] else 0
        a, b = points[i], points[(i + 1) % len(points)]
        out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
        out_tags.append(tags[i])
    return out, out_tags


def inside(poly, x, y):
    """Even-odd point-in-polygon, vectorised over arrays x, y."""
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    res = np.zeros(np.broadcast(x, y).shape, bool)
    for (ax, ay), (bx, by) in zip(poly, poly[1:] + poly[:1]):
        crosses = (ay > y) != (by > y)
        with np.errstate(divide="ignore", invalid="ignore"):
            xs = ax + (y - ay) * (bx - ax) / (by - ay)
        res ^= crosses & (x < xs)
    return res


def distance_to(poly, x, y):
    """Distance from (x, y) to the closed polyline, vectorised over arrays x, y."""
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    best = np.full(np.broadcast(x, y).shape, np.inf)
    for (ax, ay), (bx, by) in zip(poly, poly[1:] + poly[:1]):
        dx, dy = bx - ax, by - ay
        t = np.clip(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy or 1), 0, 1)
        best = np.minimum(best, np.hypot(x - ax - t * dx, y - ay - t * dy))
    return best


class HeightField:
    """sqrt of the Poisson solution inside `poly`, scaled so its highest point is `depth`."""

    def __init__(self, poly, depth):
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        self.x0, self.y0 = min(xs) - 2, min(ys) - 2
        nx = int((max(xs) + 2 - self.x0) / CELL) + 1
        ny = int((max(ys) + 2 - self.y0) / CELL) + 1
        X, Y = np.meshgrid(self.x0 + CELL * np.arange(nx), self.y0 + CELL * np.arange(ny))
        mask = inside(poly, X, Y)
        h = np.zeros((ny, nx))
        checker = (np.add.outer(np.arange(ny), np.arange(nx)) % 2).astype(bool)
        omega = 2 / (1 + math.sin(math.pi / max(nx, ny)))  # successive over-relaxation, red-black
        for _ in range(20000):
            worst = 0.0
            for colour in (False, True):
                sel = mask & (checker == colour)
                nb = np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1)
                step = (nb + 4 * CELL * CELL) / 4 - h
                h[sel] += omega * step[sel]
                worst = max(worst, float(np.abs(step[sel]).max()))
            if worst < 1e-7 * max(1.0, float(h.max())):
                break
        self.h = np.maximum(h, 0)
        self.scale = depth / math.sqrt(float(self.h.max()))
        self.f = self.scale * np.sqrt(self.h)  # for the centroid

    def _bilinear(self, g, x, y):
        gx, gy = (x - self.x0) / CELL, (y - self.y0) / CELL
        i, j = int(math.floor(gx)), int(math.floor(gy))
        if i < 0 or j < 0 or i + 1 >= g.shape[1] or j + 1 >= g.shape[0]:
            return 0.0
        u, v = gx - i, gy - j
        return float((1 - u) * (1 - v) * g[j, i] + u * (1 - v) * g[j, i + 1] + (1 - u) * v * g[j + 1, i] + u * v * g[j + 1, i + 1])

    def inflated(self, x, y):
        """The inflated solid's depth at (x, y); 0 outside the outline. Interpolates h, not its
        square root, which is steep at the outline."""
        return self.scale * math.sqrt(max(0.0, self._bilinear(self.h, x, y)))

    def at(self, x, y):
        """The front's depth at (x, y) (the back is its mirror): what the head's drawn parts sit on."""
        return self.inflated(x, y)

    def gradient(self, x, y, d=0.25):
        return ((self.at(x + d, y) - self.at(x - d, y)) / (2 * d), (self.at(x, y + d) - self.at(x, y - d)) / (2 * d))


def delaunay(points):
    """Bowyer–Watson Delaunay triangulation: triangles as index triples (counter-clockwise in y-down)."""
    pts = np.array(points, float)
    lo, hi = pts.min(0), pts.max(0)
    span, mid = (hi - lo).max() * 10, (hi + lo) / 2
    n = len(points)
    pts = np.vstack([pts, [mid + (-span, -span), mid + (span, -span), mid + (0, span)]])
    cap = 8 * n + 16
    T = np.zeros((cap, 3), int)
    C = np.zeros((cap, 3))  # circumcentre x, y and radius squared
    alive = np.zeros(cap, bool)
    count = 0

    def add(a, b, c):
        nonlocal count, T, C, alive
        if count == len(T):
            T, C, alive = (np.concatenate([T, np.zeros_like(T)]), np.concatenate([C, np.zeros_like(C)]),
                           np.concatenate([alive, np.zeros_like(alive)]))
        (ax, ay), (bx, by), (cx, cy) = pts[a], pts[b], pts[c]
        d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
        uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
        T[count] = (a, b, c)
        C[count] = (ux, uy, (ax - ux) ** 2 + (ay - uy) ** 2)
        alive[count] = True
        count += 1

    add(n, n + 1, n + 2)
    for i in range(n):
        px, py = pts[i]
        live = alive[:count]
        bad = np.nonzero(live & ((px - C[:count, 0]) ** 2 + (py - C[:count, 1]) ** 2 < C[:count, 2]))[0]
        edges = {}
        for t in bad:
            a, b, c = T[t]
            for e in ((a, b), (b, c), (c, a)):
                k = (min(e), max(e))
                edges[k] = None if k in edges else e
        alive[bad] = False
        for e in edges.values():
            if e is not None:
                add(e[0], e[1], i)
    out = []
    for a, b, c in T[:count][alive[:count]]:
        if max(a, b, c) >= n:
            continue
        (ax, ay), (bx, by), (cx, cy) = points[a], points[b], points[c]
        if (bx - ax) * (cy - ay) - (by - ay) * (cx - ax) < 0:
            b, c = c, b
        out.append((int(a), int(b), int(c)))
    return out


def build_head(pieces, neck_tag, depth):
    """The head solid and mesh. `pieces`: the outline as [(tag, cubic points)], in order round the head, each
    starting where the last ended; the outline is closed back to the start across the neck (tagged `neck_tag`). Returns (height field, outline polygon, model dict for rig.json)."""
    points, tags = [], []
    for tag, pts in pieces:
        s = bezier_samples(pts)
        if points:
            s = s[1:]
        points += s
        tags += [tag] * len(s)
    tags[-1] = neck_tag  # the stretch from the last point back to the first is the neck
    field = HeightField(points, depth)
    ears = {tag: bezier_samples(pts) for tag, pts in pieces if tag.startswith("ear")}

    boundary, btags = resample(points, tags, EDGE)
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(boundary, boundary[1:] + boundary[:1])) / 2
    turn = 1 if area > 0 else -1  # which side of the outline's direction is outside

    xs = [p[0] for p in boundary]
    ys = [p[1] for p in boundary]
    nb = len(boundary)
    inward = []
    for k in range(nb):
        (px, py), (qx, qy) = boundary[k - 1], boundary[(k + 1) % nb]
        tx, ty = qx - px, qy - py
        ln = math.hypot(tx, ty) or 1
        inward.append((-ty / ln, tx / ln) if turn > 0 else (ty / ln, -tx / ln))
    # Rings of points just inside the outline (the surface is steepest there), keeping only points that really are
    # that far inside: at a sharp inward corner an offset folds over, and those points are dropped.
    ring_pts = []
    for d in RINGS:
        cand = np.array([(x + d * ix, y + d * iy) for (x, y), (ix, iy) in zip(boundary, inward)])
        ok = inside(boundary, cand[:, 0], cand[:, 1]) & (distance_to(boundary, cand[:, 0], cand[:, 1]) > 0.7 * d)
        ring_pts += [tuple(p) for p in cand[ok]]
    # Points closer than half a ring step to one already kept are dropped too (where rings bunch up).
    kept = []
    for p in ring_pts:
        if all(math.dist(p, q) > 0.3 for q in kept[-8:]):
            kept.append(p)
    ring_pts = kept

    grid = []
    for row, y in enumerate(np.arange(min(ys) + INNER / 2, max(ys), INNER * math.sqrt(3) / 2)):
        grid += [(x, y) for x in np.arange(min(xs) + (INNER / 2 if row % 2 else 0), max(xs), INNER)]
    gx, gy = np.array([p[0] for p in grid]), np.array([p[1] for p in grid])
    ok = inside(boundary, gx, gy) & (distance_to(boundary, gx, gy) > RINGS[-1] + INNER * 0.4)
    grid = [(float(x), float(y)) for x, y, k in zip(gx, gy, ok) if k]

    # One triangulation of everything, keeping triangles inside the outline: centroid inside, and no chord between
    # two outline points that aren't neighbours leaving it (across a notch).
    flat = boundary + ring_pts + grid
    tri = delaunay(flat)
    F = np.array(flat)
    T = np.array(tri)
    centred = inside(boundary, F[T].mean(1)[:, 0], F[T].mean(1)[:, 1])
    mids = {}
    for a, b, c in tri:
        for i, j in ((a, b), (b, c), (c, a)):
            if i < nb and j < nb and (i - j) % nb not in (1, nb - 1):
                mids[(i, j)] = ((flat[i][0] + flat[j][0]) / 2, (flat[i][1] + flat[j][1]) / 2)
    keys = list(mids)
    mid_in = dict(zip(keys, inside(boundary, [mids[k][0] for k in keys], [mids[k][1] for k in keys]))) if keys else {}
    keep = [(a, b, c) for (a, b, c), ok in zip(tri, centred)
            if ok and all(mid_in.get((i, j), True) for i, j in ((a, b), (b, c), (c, a)))]
    interior = flat[nb:]  # everything but the outline has a front and a back copy

    # Vertices: the outline (z = 0, shared by both sheets), the inside's front copies, then its back copies.
    ni = len(interior)
    verts = [(x, y, 0.0) for x, y in boundary]
    for sign in (1, -1):
        verts += [(x, y, sign * field.at(x, y)) for x, y in interior]
    back = lambda i: i if i < nb else i + ni  # the back sheet's copy of a vertex (the outline is shared)
    tris = [t for t in keep] + [(back(a), back(c), back(b)) for a, b, c in keep]

    # Vertex normals from the mesh's own faces (area-weighted), so the silhouette found from them matches the
    # faces: on the outline, front and back cancel to a normal in the drawing's plane.
    acc = [[0.0, 0.0, 0.0] for _ in verts]
    for a, b, c in tris:
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = verts[a], verts[b], verts[c]
        ux, uy, uz, vx, vy, vz = bx - ax, by - ay, bz - az, cx - ax, cy - ay, cz - az
        nx_, ny_, nz_ = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        for i in (a, b, c):
            acc[i][0] += nx_
            acc[i][1] += ny_
            acc[i][2] += nz_
    normals = []
    for v in acc:
        ln = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1
        normals.append((v[0] / ln, v[1] / ln, v[2] / ln))

    # Which ear an inside vertex belongs to (inside the ear's outer curve closed across its base), so the
    # ear's shape keys bend the solid too.
    neck = [boundary[k] for k in range(nb) if btags[k] == neck_tag]
    (n0x, n0y), (n1x, n1y) = neck[0], neck[-1]

    def neck_band(x, y):  # within NECK_BAND of the neck (the engine skips the silhouette there where it faces down)
        dx, dy = n1x - n0x, n1y - n0y
        t = min(1.0, max(0.0, ((x - n0x) * dx + (y - n0y) * dy) / (dx * dx + dy * dy)))
        return math.hypot(x - n0x - t * dx, y - n0y - t * dy) < NECK_BAND

    # An ear's shape keys move it by an affine map that keeps the line between its two ends (where it meets the
    # head) in place, so everything on the ear's side of that line, between its ends, bends with it: seamlessly.
    def ear_of(x, y):
        for tag, poly in ears.items():
            (ax, ay), (bx, by) = poly[0], poly[-1]
            dx, dy = bx - ax, by - ay
            tip = max(poly, key=lambda p: abs(dx * (p[1] - ay) - dy * (p[0] - ax)))
            side = lambda px, py: dx * (py - ay) - dy * (px - ax)
            along = ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)
            if 0 <= along <= 1 and side(x, y) * side(*tip) > 0:
                return tag
        return ""

    itags = [ear_of(x, y) or (neck_tag if neck_band(x, y) else "") for x, y in interior]
    btags = [ear_of(x, y) or (tag if tag == neck_tag else "head") for (x, y), tag in zip(boundary, btags)]

    # Centre of the solid (its volume's centroid in x and y): what the head turns about.
    F = field.f
    gy_, gx_ = np.mgrid[0:F.shape[0], 0:F.shape[1]]
    total = F.sum()
    centre = (float(field.x0 + CELL * (gx_ * F).sum() / total), float(field.y0 + CELL * (gy_ * F).sum() / total))

    # The height map the engine reads every drawn point's depth from (1-unit cells): the solid's depth inside
    # the outline, minus the distance to it outside (whiskers sweep back by that).
    hx0, hy0 = math.floor(min(xs)) - 12, math.floor(min(ys)) - 12
    hw, hh = int(max(xs) + 12 - hx0) + 1, int(max(ys) + 12 - hy0) + 1
    HX, HY = np.meshgrid(hx0 + np.arange(hw), hy0 + np.arange(hh))
    hin, hdist = inside(boundary, HX, HY), distance_to(boundary, HX, HY)
    heights = [round(field.at(float(x), float(y)), 2) if k else round(-float(d), 2)
               for x, y, k, d in zip(HX.ravel(), HY.ravel(), hin.ravel(), hdist.ravel())]

    model = {
        "centre": [round(v, 3) for v in centre],
        "height": {"x0": hx0, "y0": hy0, "w": hw, "h": hh, "values": heights},
        "depth": depth,
        "verts": [round(v, 3) for p in verts for v in p],
        "normals": [round(v, 4) for p in normals for v in p],
        "tris": [i for t in tris for i in t],
        "tags": btags + itags + itags,
        "outline": nb,
        "neck": [[round(v, 3) for v in points[-1]], [round(v, 3) for v in points[0]]],  # where the cheeks meet it: right, left
    }
    return field, boundary, model
