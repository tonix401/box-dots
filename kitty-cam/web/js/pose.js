// Raw face measures (face.js) → the cat's pose for CatEngine.track(): every value is (v − rest) / (far end −
// rest) against the calibration (ranges.js), mirrored if wanted, then smoothed per channel.
import { OneEuro } from "./one-euro.js";
import { TURN, cal, leakOf, norm, restOf } from "./ranges.js";
import { opts, settings } from "./settings.js";
import { clamp, smooth } from "./util.js";

// minCutoff (Hz) / beta per channel: steady at rest, and the faster something moves the less it's
// smoothed (beta is per unit/s: yaw and pitch move ~2/s, roll ~40°/s, the lean ~15 units/s).
const FILTERS = {
  yaw: [1, 2.5], pitch: [1, 2.5], roll: [1, 0.12], x: [1, 0.3], y: [1, 0.3],
  blinkL: [6, 2], blinkR: [6, 2], gazeX: [2, 0.8], gazeY: [2, 0.8], brow: [2.5, 1],
  smile: [2.5, 1], open: [5, 2], wide: [4, 1.5], round: [4, 1.5],
};
const filters = Object.fromEntries(Object.entries(FILTERS).map(([k, [c, b]]) => [k, new OneEuro(c, b)]));

// Uncalibrated, leaning is measured from where the head has been lately (it drifts back to centre).
const drift = { tx: null, ty: null };
let gazeHold = 0; // the last trustworthy gaze: an iris can't be seen through a closed lid

// `r`: measure() of one camera frame; `dt`: seconds since the last one.
export function poseOf(r, dt) {
  if (drift.tx === null) { drift.tx = r.tx; drift.ty = r.ty; }
  const k = Math.min(1, dt / 4);
  drift.tx += (r.tx - drift.tx) * k;
  drift.ty += (r.ty - drift.ty) * k;
  const h = cal ? cal.head : { yaw: 0, pitch: 0, roll: 0, tx: drift.tx, ty: drift.ty }, b = r.b;
  const mir = opts.mirror ? -1 : 1, turn = (cal && cal.turn) || TURN;
  // Head: your own comfortable turn (from calibration) is a full turn for the cat.
  const dy = r.yaw - h.yaw, dp = r.pitch - h.pitch;
  // Mirrored, the cat moves like your reflection: turn to your left, it turns to the screen's left.
  const yaw = clamp(dy / (dy >= 0 ? turn.left : turn.right), -1.2, 1.2) * mir;
  const pitch = clamp(dp / (dp >= 0 ? turn.down : turn.up), -1.2, 1.2);
  const roll = clamp(r.roll - h.roll, -30, 30) * (opts.mirror ? 1 : -1); // rig: + is clockwise on screen
  const x = clamp((r.tx - h.tx) * 0.7, -12, 12) * mir; // cm → rig units, like yaw
  const y = clamp(-(r.ty - h.ty) * 0.7, -10, 10); // camera y points up, the rig's down

  const smile = (norm("mouthSmileLeft", b.mouthSmileLeft) + norm("mouthSmileRight", b.mouthSmileRight)) / 2;
  // Lids: the blink blendshape and the eye's own shape, each minus what the smile's squint adds.
  const lid = (bs, ear) => {
    const fromBs = clamp(norm(bs, b[bs]) - smile * leakOf("lid"), 0, 1);
    const fromShape = clamp(norm(ear, r[ear]) - smile * leakOf("lid"), 0, 1);
    return smooth(0.5 * fromBs + 0.5 * fromShape);
  };
  let lidL = lid("eyeBlinkLeft", "earL"), lidR = lid("eyeBlinkRight", "earR");
  // Blink sync: eyes that are nearly alike move as one, so a blink never turns into half a wink.
  const apart = settings.blinkSync ? smooth((Math.abs(lidL - lidR) - 0.25) / 0.25) : 1, both = (lidL + lidR) / 2;
  lidL = both + (lidL - both) * apart;
  lidR = both + (lidR - both) * apart;

  // Gaze: the iris between the eye corners (sideways), the blendshapes (up and down).
  if (both < 0.4) gazeHold = clamp((r.irisX - restOf("irisX")) / 0.12, -1, 1); // + : towards the image's right
  const gazeY = clamp(((b.eyeLookDownLeft || 0) + (b.eyeLookDownRight || 0) - (b.eyeLookUpLeft || 0) - (b.eyeLookUpRight || 0)) / 2 / 0.5, -1, 1);

  // Mouth: the gap between the lips opens it; the corners' distance against the resting mouth makes
  // it wide ("ee") or round ("oo"), with the blendshapes as a second opinion.
  const open = norm("gap", r.gap);
  const stretch = (norm("mouthStretchLeft", b.mouthStretchLeft) + norm("mouthStretchRight", b.mouthStretchRight)) / 2;
  const pucker = Math.max(norm("mouthFunnel", b.mouthFunnel), norm("mouthPucker", b.mouthPucker));
  let wide = clamp(stretch + 0.5 * smile, 0, 1), round = pucker;
  if (cal && cal.max && cal.max.width !== undefined && cal.max.narrow !== undefined) {
    const dw = r.width - cal.rest.width;
    wide = Math.max(wide, clamp(dw / (cal.max.width - cal.rest.width), 0, 1));
    round = Math.max(round, clamp(-dw / (cal.rest.width - cal.max.narrow), 0, 1) * (1 - 0.6 * open)); // "ah" pulls the corners in too
  }
  wide *= 1 - 0.7 * round;

  const raise = Math.max(norm("browInnerUp", b.browInnerUp), (norm("browOuterUpLeft", b.browOuterUpLeft) + norm("browOuterUpRight", b.browOuterUpRight)) / 2);
  const frown = clamp((norm("browDownLeft", b.browDownLeft) + norm("browDownRight", b.browDownRight)) / 2 - smile * leakOf("frown"), 0, 1);
  const pose = {
    yaw, pitch, roll, x, y,
    // Subject's left eye shows on the screen's left in a mirror, on the right otherwise.
    blinkL: opts.mirror ? lidL : lidR, blinkR: opts.mirror ? lidR : lidL,
    // Towards the image's right is towards the subject's left: the screen's left in a mirror.
    gazeX: gazeHold * mir, gazeY,
    brow: settings.ears ? clamp(raise - frown, -1, 1) : 0,
    smile: Math.max(smile, (norm("cheekSquintLeft", b.cheekSquintLeft) + norm("cheekSquintRight", b.cheekSquintRight)) / 2),
    open, wide, round,
  };
  if (!settings.trackHead) pose.yaw = pose.pitch = pose.roll = pose.x = pose.y = 0;
  if (!settings.trackBlinks) pose.blinkL = pose.blinkR = 0;
  if (!settings.trackGaze) pose.gazeX = pose.gazeY = 0;
  if (!settings.trackMouth) pose.open = pose.wide = pose.round = 0;
  for (const k in pose) pose[k] = filters[k].filter(pose[k], dt);
  return pose;
}
