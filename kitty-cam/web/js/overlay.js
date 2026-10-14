// What tracking calculated, drawn over the camera preview (Input → camera preview), so you can see what the
// cat is following: on the face, the landmarks and the measures taken from them (face.js), each with its
// value; in the corner, the pose the cat gets from them after calibration and smoothing (pose.js).
// Mirrored like the preview; the text never is. Only drawn while the preview shows.
import { LM } from "./face.js";
import { cal } from "./ranges.js";
import { opts } from "./settings.js";
import { $ } from "./util.js";

const canvas = $("cam-overlay");
const ctx = canvas.getContext("2d");
const C = { dots: "rgba(255,255,255,.35)", eye: "#7fe3ff", iris: "#ffd54a", mouth: "#ff8ad8", scale: "rgba(255,255,255,.55)",
  head: "#9dff8a", text: "#fff", panel: "rgba(10,12,16,.6)", bar: "#86d1e8", track: "rgba(255,255,255,.18)" };
const FONT = "10px system-ui, sans-serif";
const PANEL = { rowH: 10, labelW: 34, barW: 44, pad: 5 }; // the pose bars

// The pose channels the cat gets, as [label, key, min, max] (signed ranges draw from the middle).
const ROWS = [
  ["yaw", "yaw", -1.2, 1.2], ["pitch", "pitch", -1.2, 1.2], ["roll°", "roll", -30, 30],
  ["lid L", "blinkL", 0, 1], ["lid R", "blinkR", 0, 1], ["gaze x", "gazeX", -1, 1], ["gaze y", "gazeY", -1, 1],
  ["brow", "brow", -1, 1], ["smile", "smile", 0, 1], ["open", "open", 0, 1], ["wide", "wide", 0, 1], ["round", "round", 0, 1],
];

const fixed = (v, n = 2) => (v === undefined || !Number.isFinite(v) ? "–" : v.toFixed(n));

// Size the canvas to its box on screen (sharp text at any preview size); false while it has none.
function fit() {
  const dpr = devicePixelRatio || 1, w = canvas.clientWidth, h = canvas.clientHeight;
  if (!w || !h) return false;
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);
  return true;
}

// Text with a dark outline, kept inside the preview.
function label(text, x, y, color = C.text, align = "left") {
  ctx.font = FONT;
  const tw = ctx.measureText(text).width, w = canvas.clientWidth, left = align === "left" ? 0 : align === "center" ? tw / 2 : tw;
  x = Math.max(left + 3, Math.min(w - (tw - left) - 3, x));
  ctx.textAlign = align;
  ctx.textBaseline = "middle";
  ctx.lineWidth = 3;
  ctx.strokeStyle = "rgba(0,0,0,.75)";
  ctx.strokeText(text, x, y);
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
}

function line(a, b, color, width = 1.5, dash = []) {
  ctx.setLineDash(dash);
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.beginPath();
  ctx.moveTo(a[0], a[1]);
  ctx.lineTo(b[0], b[1]);
  ctx.stroke();
  ctx.setLineDash([]);
}

// The landmarks, and the measures face.js takes from them. `at(i)`: landmark i on the canvas.
function drawFace(at, landmarks, face, w, h) {
  ctx.fillStyle = C.dots;
  for (let i = 0; i < landmarks.length; i++) {
    const [x, y] = at(i);
    ctx.fillRect(x - 0.5, y - 0.5, 1, 1);
  }
  // The face's size in the image: eye corner to eye corner, what every distance is divided by; above its
  // middle, where the irises sit between the eye corners (the gaze sideways).
  const [er, el] = [at(LM.eyeOuterR), at(LM.eyeOuterL)];
  line(er, el, C.scale, 1, [3, 3]);
  label(`iris ${fixed(face.irisX)}`, (er[0] + el[0]) / 2, Math.min(er[1], el[1]) - 12, C.iris, "center");
  // Each eye's six points (their aspect ratio is how open it is), and the iris; the value beside its outer corner.
  for (const [pts, iris, outer, value] of [[LM.earR, LM.irisR, LM.eyeOuterR, face.earR], [LM.earL, LM.irisL, LM.eyeOuterL, face.earL]]) {
    ctx.strokeStyle = C.eye;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    pts.forEach((i, n) => { const [x, y] = at(i); n ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
    ctx.closePath();
    ctx.stroke();
    const [ix, iy] = at(iris);
    ctx.fillStyle = C.iris;
    ctx.beginPath();
    ctx.arc(ix, iy, 2.5, 0, 2 * Math.PI);
    ctx.fill();
    const [ox, oy] = at(outer), outward = ox < ix ? -1 : 1;
    label(`eye ${fixed(value)}`, ox + outward * 6, oy, C.eye, outward < 0 ? "right" : "left");
  }
  // The mouth: the gap between the inner lips, and corner to corner.
  const corners = [at(LM.mouthR), at(LM.mouthL)];
  line(at(LM.lipTop), at(LM.lipBottom), C.mouth, 2);
  line(corners[0], corners[1], C.mouth, 1.5);
  const below = Math.max(at(LM.lipBottom)[1], corners[0][1], corners[1][1]);
  label(`gap ${fixed(face.gap)}  width ${fixed(face.width)}`, (corners[0][0] + corners[1][0]) / 2, below + 10, C.mouth, "center");
  // The head: an arrow from the nose the way the face points, and its angles (degrees, as MediaPipe gives them).
  const nose = at(LM.noseTip), mir = opts.mirror ? -1 : 1, len = h * 0.22;
  const toward = [nose[0] + mir * Math.sin(face.yaw * Math.PI / 180) * len, nose[1] + Math.sin(face.pitch * Math.PI / 180) * len];
  line(nose, toward, C.head, 2);
  ctx.fillStyle = C.head;
  ctx.beginPath();
  ctx.arc(toward[0], toward[1], 3, 0, 2 * Math.PI);
  ctx.fill();
  label(`yaw ${fixed(face.yaw, 0)}°  pitch ${fixed(face.pitch, 0)}°  roll ${fixed(face.roll, 0)}°`, toward[0] + mir * 6, toward[1], C.head, mir < 0 ? "right" : "left");
}

// The pose the cat gets, as bars, in the top corner on the side away from the face (`faceX`).
function drawPose(pose, faceX, w) {
  const { rowH, labelW, barW, pad } = PANEL, pw = pad * 2 + labelW + barW, ph = ROWS.length * rowH + 18;
  const x = faceX < w / 2 ? w - pw - 6 : 6, y = 6;
  ctx.fillStyle = C.panel;
  ctx.fillRect(x, y, pw, ph);
  label(cal ? "pose · calibrated" : "pose · defaults", x + pad, y + 8);
  ROWS.forEach(([name, key, min, max], n) => {
    const ry = y + 17 + n * rowH, bx = x + pad + labelW, v = pose[key] ?? 0;
    label(name, x + pad, ry + rowH / 2 - 1);
    ctx.fillStyle = C.track;
    ctx.fillRect(bx, ry + 1, barW, rowH - 4);
    const zero = min < 0 ? bx + barW / 2 : bx;
    const end = bx + ((Math.max(min, Math.min(max, v)) - min) / (max - min)) * barW;
    ctx.fillStyle = C.bar;
    ctx.fillRect(Math.min(zero, end), ry + 1, Math.abs(end - zero), rowH - 4);
    if (min < 0) { // signed: mark the middle
      ctx.fillStyle = C.text;
      ctx.fillRect(zero - 0.5, ry, 1, rowH - 2);
    }
  });
}

// Every drawn frame: `landmarks` (MediaPipe's, 0..1 in the camera image), `face` (face.js's measures) and
// `pose` (what the cat got) from the last tracked frame; `tracked` false when the face is lost.
export function drawOverlay({ landmarks, face, pose, tracked }) {
  if (!opts.preview || !fit()) return;
  const w = canvas.clientWidth, h = canvas.clientHeight;
  if (!tracked || !landmarks || !face) {
    label("no face", 8, 12);
    return;
  }
  const at = i => [(opts.mirror ? 1 - landmarks[i].x : landmarks[i].x) * w, landmarks[i].y * h];
  drawFace(at, landmarks, face, w, h);
  if (pose) drawPose(pose, at(LM.noseTip)[0], w);
}
