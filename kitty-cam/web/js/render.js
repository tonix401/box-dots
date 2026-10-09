// Drawing the cat on the canvas: exactly what the call sees. Only the engine's frame decides what's drawn,
// so the cat here moves like the one in Quickshell and in the rig's preview.
import { RIG } from "./cat.js";
import { hiddenParts, opts } from "./settings.js";
import { $ } from "./util.js";

export const canvas = $("out");
const ctx = canvas.getContext("2d");
const W = canvas.width, H = canvas.height;
const [rx, ry, rw, rh] = RIG.canvas;
const S = H * 0.88 / rh; // rig units → pixels; the cat fills most of the height, centred
const ox = (W - rw * S) / 2, oy = (H - rh * S) / 2 + H * 0.02;
const pathCache = new Map();
const path2d = d => { let p = pathCache.get(d); if (!p) { p = new Path2D(d); if (pathCache.size < 4000) pathCache.set(d, p); } return p; };

// The colours in use (colours.js sets them from the theme or the pickers).
export const colors = { cat: "#b8c4ff", background: "#121318", fill: "#364379" };

// ?stamp=1: the draw time as a barcode, for measuring the delay to the camera (README.md).
const STAMP = new URLSearchParams(location.search).get("stamp") === "1";

// The cat's outline, piece by piece around it, as [part, variant, shape, reversed]: filled in behind the
// lines (Colours → fill) so a busy background never shows through the cat, e.g. once OBS keys the
// background colour out. Built every frame from the live paths, so it follows tilts, squashes and ears.
const OUTLINE_HEAD = [["head", "default", 0], ["ear-l", "default", 0], ["head", "default", 1], ["ear-r", "default", 0], ["head", "default", 2]];
const OUTLINE_BODY = { // from the neck's right side round the feet to its left
  slim: [["body", "slim", 2, true], ["body", "slim", 4, true], ["body", "slim", 1, true], ["body", "slim", 3, true], ["body", "slim", 0, true]],
  fat: [["body", "fat", 0, true]],
};

function piecePoints(f, [part, variant, i, reversed]) {
  const moved = f.paths[part] && f.paths[part][variant];
  let pts;
  if (moved) { // shape keys or skinning moved it: read the points back out of its path
    const n = moved[i].match(/-?[\d.]+(?:e-?\d+)?/g).map(Number);
    pts = [];
    for (let k = 0; k + 1 < n.length; k += 2) pts.push([n[k], n[k + 1]]);
  } else pts = RIG.parts[part].variants[variant][i].paths[0].pts;
  const m = f.worlds[part];
  pts = pts.map(([x, y]) => [m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]]);
  return reversed ? pts.reverse() : pts;
}

// The pieces chained into one closed path (world coordinates), through `extra` points before it closes.
function chained(f, pieces, extra = []) {
  const p = new Path2D();
  pieces.forEach((piece, n) => {
    const pts = piecePoints(f, piece);
    if (n === 0) p.moveTo(pts[0][0], pts[0][1]);
    else p.lineTo(pts[0][0], pts[0][1]);
    for (let k = 1; k + 2 < pts.length; k += 3) p.bezierCurveTo(pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1], pts[k + 2][0], pts[k + 2][1]);
  });
  for (const [x, y] of extra) p.lineTo(x, y);
  p.closePath();
  return p;
}

// At rest the head's outline pieces and the body's make one closed shape. While the 3D head is turned, its
// outline is its silhouette (f.outline, head space), filled on its own, and the body is closed through where the
// cheeks meet the neck (f.neck: the body's ends are a little outside the cheeks', and the wedge between them
// would otherwise stay unfilled); the two overlap along the neck, so they still fill as one.
function drawFill(f) {
  const body = (f.variantOpacity["body/fat"] || 0) > (f.variantOpacity["body/slim"] || 0) ? "fat" : "slim";
  ctx.globalAlpha = 1;
  ctx.fillStyle = colors.fill;
  ctx.setTransform(S, 0, 0, S, ox - S * rx, oy - S * ry);
  if (!f.outline) {
    ctx.fill(chained(f, OUTLINE_HEAD.concat(OUTLINE_BODY[body])));
    return;
  }
  ctx.fill(chained(f, OUTLINE_BODY[body], [f.neck[1], f.neck[0]])); // the body runs right to left round the feet
  const m = f.worlds.head, head = path2d(f.outline);
  ctx.setTransform(S * m[0], S * m[1], S * m[2], S * m[3], S * (m[4] - rx) + ox, S * (m[5] - ry) + oy);
  ctx.fill(head);
  // Traced as well, so no anti-aliased hairline shows where it meets the body's fill (within the outline's stroke).
  ctx.lineWidth = 1.5;
  ctx.lineJoin = "round";
  ctx.strokeStyle = colors.fill;
  ctx.stroke(head);
}

function drawStamp() {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  const t = Date.now() % 2 ** 32;
  ctx.fillStyle = "#f00"; // red end marks, so the bars can be found in a screenshot too
  ctx.fillRect(0, 0, 24, 24);
  ctx.fillRect(33 * 24, 0, 24, 24);
  for (let bit = 0; bit < 32; bit++) {
    ctx.fillStyle = Math.floor(t / 2 ** bit) % 2 ? "#fff" : "#000";
    ctx.fillRect((bit + 1) * 24, 0, 24, 24);
  }
}

// One frame from CatEngine.step().
export function draw(f) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.fillStyle = colors.background;
  ctx.fillRect(0, 0, W, H);
  if (opts.fill) drawFill(f);
  ctx.lineCap = "round";
  ctx.miterLimit = 4; // as SVG, so the miter joins match the rig's preview and the kitty cats
  ctx.lineWidth = RIG.stroke.width;
  ctx.strokeStyle = ctx.fillStyle = colors.cat;
  for (const name of RIG.order) {
    const part = RIG.parts[name], po = f.partOpacity[name];
    if (po <= 0.01 || hiddenParts.has(name)) continue;
    const m = f.worlds[name];
    ctx.setTransform(S * m[0], S * m[1], S * m[2], S * m[3], S * (m[4] - rx) + ox, S * (m[5] - ry) + oy);
    for (const v in part.variants) {
      const vo = f.variantOpacity[name + "/" + v];
      if (vo <= 0.01) continue;
      const moved = f.paths[name] && f.paths[name][v];
      part.variants[v].forEach((s, i) => {
        const so = f.shapeOpacity[name + "/" + i];
        const alpha = po * vo * (so === undefined ? 1 : so);
        if (alpha <= 0.01) return;
        const p = path2d(moved ? moved[i] : s.d);
        if (s.fill) { ctx.globalAlpha = alpha * s.alpha; ctx.fill(p, s.evenodd ? "evenodd" : "nonzero"); }
        if (s.stroke) { ctx.globalAlpha = alpha; ctx.lineJoin = s.join; ctx.stroke(p); }
      });
    }
  }
  if (STAMP) drawStamp();
}
