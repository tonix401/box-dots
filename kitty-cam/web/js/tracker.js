// MediaPipe's Face Landmarker, served by kitty-cam from its download cache (/vendor/): on the GPU if it can,
// else on the CPU.
import { FaceLandmarker, FilesetResolver } from "/vendor/vision_bundle.mjs";
import { failed } from "./util.js";

export let landmarker = null; // until it has loaded

async function open() {
  const files = await FilesetResolver.forVisionTasks("/vendor/wasm");
  const options = delegate => ({
    baseOptions: { modelAssetPath: "/vendor/face_landmarker.task", delegate },
    runningMode: "VIDEO", numFaces: 1, outputFaceBlendshapes: true, outputFacialTransformationMatrixes: true,
  });
  try { landmarker = await FaceLandmarker.createFromOptions(files, options("GPU")); }
  catch (e) { console.warn("kitty-cam: GPU delegate failed, using the CPU", e); landmarker = await FaceLandmarker.createFromOptions(files, options("CPU")); }
}

export function initTracker() {
  open().catch(failed("MediaPipe failed", "s-track"));
}
