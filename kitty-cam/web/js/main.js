// Kitty Cam's page: wires the cards up, then runs the loop that tracks the face, draws the cat and sends
// the frame. Each part lives in its own module; this one only connects them.
import * as calibration from "./calibration.js";
import { CatEngine, st } from "./cat.js";
import { initColours } from "./colours.js";
import { measure } from "./face.js";
import { initInput, video } from "./input.js";
import { mic, micLevel } from "./mic.js";
import { initMoods, names, setMood } from "./moods.js";
import { drawOverlay } from "./overlay.js";
import { poseOf } from "./pose.js";
import { cal } from "./ranges.js";
import { canvas, draw } from "./render.js";
import { output, send } from "./sender.js";
import { applySettings, opts, renderSettings, settings } from "./settings.js";
import { initTracker, landmarker } from "./tracker.js";
import { $, store } from "./util.js";

// ── the cards ──
function initActions() {
  $("act-hop").onclick = () => CatEngine.act(st, "hop", 1);
  const squish = $("act-squish");
  squish.onpointerdown = e => { squish.setPointerCapture(e.pointerId); CatEngine.press(st, true); squish.classList.add("on"); };
  squish.onpointerup = squish.onpointercancel = () => { CatEngine.press(st, false); squish.classList.remove("on"); };
  squish.onclick = e => { // from the keyboard (Enter/Space on the button): a short squish
    if (e.detail !== 0) return;
    CatEngine.press(st, true);
    setTimeout(() => CatEngine.press(st, false), 450);
  };
}

// The "fill" (remembered) and "camera preview" (not) switches.
function initToggle(id) {
  const b = $(id);
  const sync = () => {
    b.classList.toggle("on", opts[id]);
    $("preview-box").classList.toggle("shown", opts.preview);
  };
  b.onclick = () => { opts[id] = !opts[id]; if (id !== "preview") store.set(id, opts[id]); sync(); };
  sync();
}

// The cards you set up once (input, calibration, colours) fold away; which are open is remembered.
// Calibration starts open until a neutral face is recorded.
function initFolds() {
  const folds = store.get("open", {});
  for (const d of document.querySelectorAll("details.card")) {
    const key = d.dataset.key;
    d.open = key in folds ? folds[key] : key === "calibration" ? !(store.get("calibration-steps", {}).neutral) : false;
    d.addEventListener("toggle", () => { folds[key] = d.open; store.set("open", folds); });
  }
}

// Keys while this window is focused: 1–9 moods, 0 neutral, Space hop, hold S squish, C neutral face.
function initKeys() {
  addEventListener("keydown", e => {
    if (e.ctrlKey || e.altKey || e.metaKey || e.target.tagName === "INPUT") return;
    if (e.target.tagName === "BUTTON" && (e.key === " " || e.key === "Enter")) return; // the button's own
    if (e.key >= "1" && e.key <= "9" && names[+e.key - 1]) setMood(names[+e.key - 1]);
    else if (e.key === "0") setMood("neutral");
    else if (e.key === " ") { CatEngine.act(st, "hop", 1); e.preventDefault(); }
    else if ((e.key === "s" || e.key === "S") && !e.repeat) CatEngine.press(st, true);
    else if (e.key === "c" || e.key === "C") calibration.recordStep("neutral");
  });
  addEventListener("keyup", e => { if (e.key === "s" || e.key === "S") CatEngine.press(st, false); });
}

// ── the loop ──
// A timer, not requestAnimationFrame: the compositor stops sending frame callbacks to a covered or hidden
// window, and the call still needs frames then (kitty-cam turns timer throttling off). It looks for a new
// camera frame twice per camera frame, so none slips between two polls (at the camera's own 30 Hz the two
// drift past each other). The cat is drawn and sent at 30 fps.
const FPS = 30, POLL_HZ = 60;
let last = performance.now(), lastDetect = performance.now(), lastVideoTime = -1, lastSeen = -1e9;
let detections = 0, detectMs = 0, statWindow = performance.now(), lastStats = "{}";

// A new camera frame, if there is one: detect the face and steer the cat with it.
function track(now) {
  if (!landmarker || video.readyState < 2 || video.currentTime === lastVideoTime) return;
  lastVideoTime = video.currentTime;
  const dt = Math.min((now - lastDetect) / 1000, 0.1); // the filters run per camera frame
  lastDetect = now;
  const t0 = performance.now();
  const result = landmarker.detectForVideo(video, now);
  detectMs += performance.now() - t0;
  detections++;
  if (!result.faceBlendshapes.length || !result.facialTransformationMatrixes.length) return;
  const face = debug.raw = measure(result, video);
  debug.landmarks = result.faceLandmarks[0];
  lastSeen = now;
  if (calibration.isRecording()) calibration.sample(face);
  debug.pose = poseOf(face, dt);
  CatEngine.track(st, debug.pose);
}

// Once a second: the status bar, and the figures kitty-cam's /status shows.
function report(now, tracked) {
  const secs = (now - statWindow) / 1000;
  $("s-track").textContent = !landmarker ? "loading MediaPipe…" : `${Math.round(detections / secs)} fps · ${tracked ? "face found" : "no face"}`;
  $("s-track").className = landmarker && tracked ? "ok" : "";
  $("s-out").textContent = { ok: `live · ${Math.round(output.sent / secs)} fps`, none: "not reaching the camera (see kitty-cam's output)", down: "kitty-cam not running", error: "error" }[output.state] || "–";
  $("s-out").className = output.state === "ok" ? "ok" : output.state ? "bad" : "";
  const camTrack = video.srcObject && video.srcObject.getVideoTracks()[0];
  const steps = calibration.recordedSteps();
  lastStats = JSON.stringify({
    detectFps: Math.round(detections / secs), detectMs: detections ? +(detectMs / detections).toFixed(1) : null,
    cameraFps: camTrack ? camTrack.getSettings().frameRate : null, face: tracked, calibrated: steps.length ? steps.join(" ") : "none",
    camera: video.videoWidth ? `${video.videoWidth}x${video.videoHeight}` : null,
  });
  detections = output.sent = detectMs = 0;
  statWindow = now;
}

function tick() {
  const now = performance.now();
  track(now);
  if (now - last < 1000 / FPS - 2) return; // drawing and sending: 30 fps
  const dt = Math.min((now - last) / 1000, 0.1);
  last = now;
  if (calibration.isRecording()) calibration.tick(now);
  const talk = micLevel(dt);
  $("s-mic").value = talk;
  const tracked = now - lastSeen < 300; // brief misses keep the last pose
  if (!tracked) CatEngine.track(st, null);
  if (settings.mic && talk > 0.05) {
    if (tracked && st.pose) st.pose.open = Math.max(st.pose.open, 0.7 * talk);
    else CatEngine.voice(st, [1, 0.8 * talk, 0, 0]); // no face: talk with the mic alone
  } else CatEngine.voice(st, [0, 0, 0, 0]);
  draw(CatEngine.step(st, dt));
  send(canvas, lastStats);
  drawOverlay({ landmarks: debug.landmarks, face: debug.raw, pose: debug.pose, tracked });
  if (now - statWindow >= 1000) report(now, tracked);
}

// The last tracked frame (the preview's overlay draws it), also for tuning from the devtools console:
// kittyCam.raw is the face as MediaPipe saw it, kittyCam.pose what the cat got from it.
const debug = window.kittyCam = { st, opts, mic, settings, get cal() { return cal; }, raw: null, landmarks: null, pose: null };

// ── start ──
initColours();
initMoods();
initActions();
initToggle("fill");
initToggle("preview");
initFolds();
initInput();
initTracker();
calibration.initCalibration();
initKeys();
applySettings();
renderSettings();
draw(CatEngine.step(st, 0));
setInterval(tick, 1000 / POLL_HZ);
