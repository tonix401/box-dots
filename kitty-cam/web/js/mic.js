// The mic: loudness over the room's noise floor keeps the mouth moving while you talk. Its AudioContext also
// plays the calibration's beep.
import { smooth } from "./util.js";

export const mic = { talk: 0, floor: -60, analyser: null, buf: null, ac: null };
let source = null;

// Listen to `stream` (a new mic has its own noise floor).
export function listen(stream) {
  if (!mic.ac) {
    const ac = mic.ac = new AudioContext();
    mic.analyser = ac.createAnalyser();
    mic.analyser.fftSize = 1024;
    mic.buf = new Float32Array(mic.analyser.fftSize);
    if (ac.state !== "running") document.addEventListener("pointerdown", () => ac.resume(), { once: true });
  }
  if (source) source.disconnect();
  source = mic.ac.createMediaStreamSource(stream);
  source.connect(mic.analyser);
  mic.floor = -60;
}

// How much you're talking, 0..1, once per drawn frame.
export function micLevel(dt) {
  if (!mic.analyser) return 0;
  mic.analyser.getFloatTimeDomainData(mic.buf);
  let sum = 0;
  for (const v of mic.buf) sum += v * v;
  const db = 10 * Math.log10(sum / mic.buf.length + 1e-10);
  // The floor follows quiet stretches down at once and creeps up slowly through speech.
  mic.floor = db < mic.floor ? db : mic.floor + (db - mic.floor) * Math.min(1, dt / 20);
  const goal = smooth((db - mic.floor - 6) / 20);
  mic.talk += (goal - mic.talk) * Math.min(1, dt / (goal > mic.talk ? 0.03 : 0.09)); // quick to open, slower to close
  return mic.talk;
}

// "Done": a short beep, your cue to relax (or open your eyes again).
export function beep() {
  if (!mic.ac) return;
  const o = mic.ac.createOscillator(), g = mic.ac.createGain();
  o.frequency.value = 880;
  g.gain.setValueAtTime(0.15, mic.ac.currentTime);
  g.gain.exponentialRampToValueAtTime(0.001, mic.ac.currentTime + 0.25);
  o.connect(g).connect(mic.ac.destination);
  o.start();
  o.stop(mic.ac.currentTime + 0.25);
}
