// The Input card: which camera and microphone to use. The choice is remembered (Chromium keeps device ids
// stable per site); a remembered device that's gone falls back to the default. Kitty Cam's own camera and mic
// are never offered or used. The mic picked here is also the one kitty-cam puts into Kitty Cam Mic (POST /mic).
import { listen } from "./mic.js";
import { cal } from "./ranges.js";
import { $, failed, store } from "./util.js";

export const video = $("cam");
let camStream = null, micStream = null;
const isKittyCam = label => (label || "").includes("Kitty Cam");

async function openCamera(id = store.get("camera", null)) {
  // 720p: MediaPipe works on a crop around the face, so more pixels there means finer lips and lids.
  const want = { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } };
  const get = deviceId => navigator.mediaDevices.getUserMedia({ video: deviceId ? { ...want, deviceId: { exact: deviceId } } : want });
  if (camStream) camStream.getTracks().forEach(t => t.stop());
  let stream = id ? await get(id).catch(() => get(null)) : await get(null);
  if (isKittyCam(stream.getVideoTracks()[0].label)) {
    stream.getTracks().forEach(t => t.stop());
    const cams = (await navigator.mediaDevices.enumerateDevices()).filter(d => d.kind === "videoinput" && !isKittyCam(d.label));
    if (!cams.length) throw new Error("no camera besides Kitty Cam");
    stream = await get(cams[0].deviceId);
  }
  camStream = video.srcObject = stream;
  stream.getVideoTracks()[0].onended = () => keepCamera(); // lost (unplugged, PipeWire restarted); stop() doesn't fire it
  await video.play();
  $("s-cam").textContent = ""; // the select shows which camera; this note is for problems only
  refreshDevices();
}

async function openMic(id = store.get("microphone", null)) {
  const want = { echoCancellation: false, noiseSuppression: true, autoGainControl: false };
  const get = deviceId => navigator.mediaDevices.getUserMedia({ audio: deviceId ? { ...want, deviceId: { exact: deviceId } } : want });
  if (micStream) micStream.getTracks().forEach(t => t.stop());
  micStream = id ? await get(id).catch(() => get(null)) : await get(null);
  if (isKittyCam(micStream.getAudioTracks()[0].label)) { // the soundboard would hear itself
    micStream.getTracks().forEach(t => t.stop());
    const mics = (await navigator.mediaDevices.enumerateDevices()).filter(d => d.kind === "audioinput" && d.deviceId !== "default" && !isKittyCam(d.label));
    if (!mics.length) throw new Error("no microphone besides Kitty Cam Mic");
    micStream = await get(mics[0].deviceId);
  }
  listen(micStream);
  fetch("mic", { method: "POST", body: JSON.stringify({ label: micStream.getAudioTracks()[0].label }) }).catch(() => {});
  $("s-mic-name").textContent = "";
  refreshDevices();
}

// The camera, kept trying: if it can't be opened (seen 2026-10-13: "Requested device not found" in the window
// while the webcam itself was fine; a restart fixed it), try again every few seconds and whenever devices change.
let camRetry = 0;
function keepCamera() {
  clearTimeout(camRetry);
  openCamera().catch(e => {
    failed("camera failed", "s-cam")(e);
    $("s-cam").textContent += " (trying again…)";
    camRetry = setTimeout(keepCamera, 5000);
  });
}
const cameraLive = () => camStream && camStream.getVideoTracks().some(t => t.readyState === "live");

async function refreshDevices() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const fill = (sel, kind, stream, skip) => {
    const current = stream && stream.getTracks()[0] ? stream.getTracks()[0].getSettings().deviceId : null;
    const list = devices.filter(d => d.kind === kind && d.deviceId && !skip(d.label));
    sel.replaceChildren(...list.map((d, i) => new Option(d.label || `${kind === "videoinput" ? "Camera" : "Microphone"} ${i + 1}`, d.deviceId, false, d.deviceId === current)));
  };
  fill($("sel-cam"), "videoinput", camStream, isKittyCam);
  fill($("sel-mic"), "audioinput", micStream, isKittyCam);
}

export function initInput() {
  $("sel-cam").onchange = e => {
    store.set("camera", e.target.value);
    openCamera(e.target.value).then(() => {
      // Another camera sees you from another place: the head's neutral position has moved.
      if (cal) $("hint").textContent = "Camera changed: record the neutral face again (C) so the cat's resting head matches; the head turns may need redoing too.";
    }).catch(failed("camera failed", "s-cam"));
  };
  $("sel-mic").onchange = e => { store.set("microphone", e.target.value); openMic(e.target.value).catch(failed("mic failed", "s-mic-name")); };
  navigator.mediaDevices.addEventListener("devicechange", () => { refreshDevices(); if (!cameraLive()) keepCamera(); });
  keepCamera();
  openMic().catch(failed("mic failed", "s-mic-name"));
}
