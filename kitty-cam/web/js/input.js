// The Input card: which camera and microphone to use. The choice is remembered (Chromium keeps device ids
// stable per site); a remembered device that's gone falls back to the default. Kitty Cam's own camera is
// never offered or tracked.
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
  await video.play();
  $("s-cam").textContent = ""; // the select shows which camera; this note is for problems only
  refreshDevices();
}

async function openMic(id = store.get("microphone", null)) {
  const want = { echoCancellation: false, noiseSuppression: true, autoGainControl: false };
  const get = deviceId => navigator.mediaDevices.getUserMedia({ audio: deviceId ? { ...want, deviceId: { exact: deviceId } } : want });
  if (micStream) micStream.getTracks().forEach(t => t.stop());
  micStream = id ? await get(id).catch(() => get(null)) : await get(null);
  listen(micStream);
  $("s-mic-name").textContent = "";
  refreshDevices();
}

async function refreshDevices() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const fill = (sel, kind, stream, skip) => {
    const current = stream && stream.getTracks()[0] ? stream.getTracks()[0].getSettings().deviceId : null;
    const list = devices.filter(d => d.kind === kind && d.deviceId && !skip(d.label));
    sel.replaceChildren(...list.map((d, i) => new Option(d.label || `${kind === "videoinput" ? "Camera" : "Microphone"} ${i + 1}`, d.deviceId, false, d.deviceId === current)));
  };
  fill($("sel-cam"), "videoinput", camStream, isKittyCam);
  fill($("sel-mic"), "audioinput", micStream, () => false);
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
  navigator.mediaDevices.addEventListener("devicechange", () => refreshDevices());
  openCamera().catch(failed("camera failed", "s-cam"));
  openMic().catch(failed("mic failed", "s-mic-name"));
}
