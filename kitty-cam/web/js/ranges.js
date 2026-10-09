// How far each tracked measure moves: the defaults, and the calibration that replaces them with your own.
// `rest` is the neutral face, `max` the far end of each movement (for the eye ratios: eyes closed, a smaller
// number), `turn` how far you turn your head when asked, `leak` what a big smile does to the lids and brows
// by itself (MediaPipe sees its squint as blinking and frowning).
import { clamp } from "./util.js";

export const BS_REST = { jawOpen: 0.03, eyeBlinkLeft: 0.2, eyeBlinkRight: 0.2, mouthSmileLeft: 0.05, mouthSmileRight: 0.05,
  mouthFunnel: 0.02, mouthPucker: 0.05, mouthStretchLeft: 0.02, mouthStretchRight: 0.02, browInnerUp: 0.05,
  browOuterUpLeft: 0.02, browOuterUpRight: 0.02, browDownLeft: 0.05, browDownRight: 0.05, cheekSquintLeft: 0.02, cheekSquintRight: 0.02 };
export const REST = { ...BS_REST, gap: 0.02, earL: 0.28, earR: 0.28, irisX: 0.5 };
export const MAX = { jawOpen: 0.5, eyeBlinkLeft: 0.65, eyeBlinkRight: 0.65, mouthSmileLeft: 0.7, mouthSmileRight: 0.7,
  mouthFunnel: 0.45, mouthPucker: 0.7, mouthStretchLeft: 0.35, mouthStretchRight: 0.35, browInnerUp: 0.6,
  browOuterUpLeft: 0.5, browOuterUpRight: 0.5, browDownLeft: 0.5, browDownRight: 0.5, cheekSquintLeft: 0.5, cheekSquintRight: 0.5,
  gap: 0.45, earL: 0.1, earR: 0.1 };
export const TURN = { left: 25, right: 25, up: 15, down: 18 }; // degrees from the neutral head that count as "all the way"
const LEAK = { lid: 0.25, frown: 1 }; // uncalibrated, a guess

// The calibration in use (calibration.js works it out from the recorded movements), null for the defaults.
export let cal = null;
export const setCal = c => { cal = c; };

export const restOf = (k, c = cal) => (c && c.rest[k] !== undefined ? c.rest[k] : REST[k]);
export const maxOf = (k, c = cal) => (c && c.max && c.max[k] !== undefined ? c.max[k] : MAX[k]);
export const leakOf = (k, c = cal) => (c && c.leak && c.leak[k] !== undefined ? c.leak[k] : LEAK[k]);

// 0 at rest, 1 at the far end (works for ranges that shrink, like the eye ratios).
export function norm(k, v, c = cal) {
  const from = restOf(k, c), span = maxOf(k, c) - from;
  return Math.abs(span) < 1e-4 ? 0 : clamp((v - from) / span, 0, 1);
}
