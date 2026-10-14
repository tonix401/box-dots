// The Calibration card. One button per movement, recorded whenever you're ready (and redone any time): a
// short count-in, then ~1.5 s of samples, then a beep. Every recording is kept (localStorage), and the
// calibration is worked out again from all of them: the neutral face gives every resting value and the
// head's zero, the others the far end of their movement, so the cat's widest mouth is your widest mouth,
// your comfortable head turn is its full turn, and a smile's squint stops reading as a blink.
import { beep } from "./mic.js";
import { BS_REST, MAX, REST, TURN, cal, norm, setCal } from "./ranges.js";
import { $, clamp, store } from "./util.js";

const STEPS = { // id: [button, instruction]
  neutral: ["Neutral face", "Relax and look at the screen, mouth closed"],
  open: ["Mouth wide open", "Open your mouth as wide as you can"],
  smile: ["Big smile", "Big smile!"],
  ee: ["“Eee”", "Say “eee”: lips stretched wide"],
  oo: ["“Ooo”", "Say “ooo”: lips round and pushed forward"],
  brows: ["Brows up", "Raise your eyebrows"],
  frown: ["Frown", "Frown"],
  closed: ["Eyes closed", "Close both eyes now, open them at the beep"],
  left: ["Head left", "Turn your head to your left"],
  right: ["Head right", "Turn your head to your right"],
  up: ["Head up", "Tilt your head back: look up"],
  down: ["Head down", "Tilt your head forward: look down"],
};
const STEP_GROUPS = [["", ["neutral"]], ["Mouth", ["open", "smile", "ee", "oo"]], ["Eyes & brows", ["brows", "frown", "closed"]], ["Head", ["left", "right", "up", "down"]]];
const READY_MS = 1200, HOLD_MS = 1500;
const ROW_KEYS = ["yaw", "pitch", "roll", "tx", "ty", "gap", "width", "earL", "earR", "irisX"];
const round4 = v => Math.round(v * 1e4) / 1e4;
const reduced = r => { // what the calibration needs from a frame, small enough to keep
  const o = { b: {} };
  for (const k of ROW_KEYS) o[k] = round4(r[k]);
  for (const k in BS_REST) o.b[k] = round4(r.b[k]);
  return o;
};

let recordings = store.get("calibration-steps", {});
let recording = null; // {id, start, samples} while a step records

export const isRecording = () => recording !== null;
export const recordedSteps = () => Object.keys(recordings);

export function recordStep(id) {
  if (recording) return;
  recording = { id, start: performance.now(), samples: [] };
  show();
}

// Every tracked camera frame while a step records.
export function sample(r) {
  if (recording && performance.now() - recording.start > READY_MS) recording.samples.push(reduced(r));
}

// Every drawn frame while a step records: the countdown, and the end of the step.
export function tick(now) {
  const rec = recording, t = now - rec.start;
  const [, say] = STEPS[rec.id];
  $("hint").innerHTML = t < READY_MS
    ? `<strong class="step">${say}</strong> <span>get ready… ${Math.ceil((READY_MS - t) / 1000)}</span>`
    : `<strong class="step">${say}</strong> <span>hold it…</span>`;
  if (t < READY_MS + HOLD_MS) return;
  recording = null;
  beep();
  if (rec.samples.length < 8) {
    $("hint").textContent = "Couldn't see your face well enough; try that one again (good light helps).";
  } else {
    recordings[rec.id] = rec.samples;
    store.set("calibration-steps", recordings);
    setCal(calibrate(recordings));
    $("hint").textContent = `Recorded: ${STEPS[rec.id][0]}.` + (recordings.neutral ? "" : " Now the neutral face too: the others are measured against it.");
  }
  show();
}

function show() {
  const button = id => {
    const b = document.createElement("button");
    b.className = (id === "neutral" ? "neutral" : "") + (recording && recording.id === id ? " rec" : "");
    b.disabled = !!recording && recording.id !== id;
    b.innerHTML = `<span>${STEPS[id][0]}</span>` + (recordings[id] ? `<span class="done" title="recorded; click to redo">✓</span>` : "");
    b.onclick = () => recordStep(id);
    return b;
  };
  $("calib").replaceChildren(...STEP_GROUPS.flatMap(([label, ids]) => {
    const grid = document.createElement("div");
    grid.className = "calib-group";
    grid.append(...ids.map(button));
    if (!label) return [grid];
    const h = document.createElement("h3");
    h.textContent = label;
    return [h, grid];
  }));
  const n = Object.keys(STEPS).filter(id => recordings[id]).length;
  $("calib-count").textContent = `${n} of ${Object.keys(STEPS).length} recorded`;
}

// Robust picks from a step's samples: the mean, and a high or low percentile (ignores the odd bad frame).
const pick = (rows, f, q) => {
  const v = rows.map(f).filter(Number.isFinite).sort((a, c) => a - c);
  if (!v.length) return undefined;
  return q === undefined ? v.reduce((a, c) => a + c, 0) / v.length : v[Math.min(v.length - 1, Math.floor(q * v.length))];
};

// The calibration from every recorded step (ranges.js), or null without a neutral face.
function calibrate(S) {
  const n = S.neutral;
  if (!n || n.length < 8) return null;
  const c = { v: 3, rest: {}, max: {}, leak: {}, turn: { ...TURN } };
  c.head = { yaw: pick(n, r => r.yaw), pitch: pick(n, r => r.pitch), roll: pick(n, r => r.roll), tx: pick(n, r => r.tx), ty: pick(n, r => r.ty) };
  for (const k in BS_REST) c.rest[k] = pick(n, r => r.b[k]);
  for (const k of ["gap", "width", "earL", "earR", "irisX"]) c.rest[k] = pick(n, r => r[k]);
  // A far end only counts if the movement clearly happened (else the default stays).
  const far = (k, rows, f, q) => {
    if (!rows || rows.length < 5) return;
    const v = pick(rows, f, q), def = MAX[k] !== undefined ? MAX[k] - REST[k] : null;
    if (v === undefined) return;
    if (def !== null && Math.abs(v - c.rest[k]) < 0.3 * Math.abs(def)) return;
    c.max[k] = v;
  };
  far("jawOpen", S.open, r => r.b.jawOpen, 0.9);
  far("gap", S.open, r => r.gap, 0.9);
  for (const k of ["mouthSmileLeft", "mouthSmileRight", "cheekSquintLeft", "cheekSquintRight"]) far(k, S.smile, r => r.b[k], 0.9);
  for (const k of ["mouthStretchLeft", "mouthStretchRight"]) far(k, S.ee, r => r.b[k], 0.9);
  for (const k of ["mouthFunnel", "mouthPucker"]) far(k, S.oo, r => r.b[k], 0.9);
  for (const k of ["browInnerUp", "browOuterUpLeft", "browOuterUpRight"]) far(k, S.brows, r => r.b[k], 0.9);
  for (const k of ["browDownLeft", "browDownRight"]) far(k, S.frown, r => r.b[k], 0.9);
  for (const k of ["eyeBlinkLeft", "eyeBlinkRight"]) far(k, S.closed, r => r.b[k], 0.9);
  for (const k of ["earL", "earR"]) far(k, S.closed, r => r[k], 0.1);
  // Mouth width: the widest of "eee" and the smile, the narrowest of "ooo".
  const widest = Math.max(pick(S.ee || [], r => r.width, 0.9) || 0, pick(S.smile || [], r => r.width, 0.9) || 0);
  if (widest > c.rest.width * 1.05) c.max.width = widest;
  const narrowest = pick(S.oo || [], r => r.width, 0.1);
  if (narrowest !== undefined && narrowest < c.rest.width * 0.95) c.max.narrow = narrowest;
  // Head range: how far you turn when asked, as "all the way" (at least 8°, so a nod can't overshoot).
  const reach = (rows, f, q, key) => { const v = rows && rows.length >= 5 ? pick(rows, f, q) : undefined; if (v !== undefined && v > 8) c.turn[key] = v; };
  reach(S.left, r => r.yaw - c.head.yaw, 0.9, "left"); // your left is the image's right: yaw +
  reach(S.right, r => c.head.yaw - r.yaw, 0.9, "right");
  reach(S.up, r => c.head.pitch - r.pitch, 0.9, "up");
  reach(S.down, r => r.pitch - c.head.pitch, 0.9, "down");
  // What the smile does to the lids and brows by itself, as a fraction of their range (measured against
  // this calibration's own rest and far ends).
  if (S.smile && S.smile.length >= 5) {
    const lidAt = r => Math.max((norm("eyeBlinkLeft", r.b.eyeBlinkLeft, c) + norm("eyeBlinkRight", r.b.eyeBlinkRight, c)) / 2,
      (norm("earL", r.earL, c) + norm("earR", r.earR, c)) / 2);
    c.leak.lid = clamp(pick(S.smile, lidAt), 0, 0.8);
    c.leak.frown = clamp(pick(S.smile, r => (norm("browDownLeft", r.b.browDownLeft, c) + norm("browDownRight", r.b.browDownRight, c)) / 2), 0, 1);
  }
  return c;
}

export function initCalibration() {
  if (store.get("calibration", null)) store.set("calibration", null); // the older, all-in-one format
  setCal(calibrate(recordings));
  show();
  $("uncalibrate").onclick = () => {
    recordings = {};
    store.set("calibration-steps", {});
    setCal(null);
    show();
    $("hint").textContent = "Calibration reset.";
  };
  if (!cal) $("hint").textContent = "Tip: record a neutral face (C), then whichever movements you like, so the cat follows your own face's range.";
}
