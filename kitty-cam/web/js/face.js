// A MediaPipe result as raw measures, straight from the face (subject's left/right, unmirrored camera
// space), so calibration doesn't depend on the mirror switch: the 52 blendshapes, the head from the
// transformation matrix, and measures taken from the landmarks themselves, which follow the lips and lids
// more directly. Distances are scaled by the face's size in the image, so they hold at any distance.
export const LM = { // MediaPipe face mesh indices; R = the subject's right eye (the image's left)
  eyeOuterR: 33, eyeInnerR: 133, eyeOuterL: 263, eyeInnerL: 362,
  lipTop: 13, lipBottom: 14, mouthR: 61, mouthL: 291, noseTip: 1,
  earR: [33, 160, 158, 133, 153, 144], earL: [362, 385, 387, 263, 373, 380], irisR: 468, irisL: 473,
};

export function measure(result, video) {
  const b = {};
  for (const c of result.faceBlendshapes[0].categories) b[c.categoryName] = c.score;
  const m = result.facialTransformationMatrixes[0].data; // column-major 4×4, canonical face → camera (cm)
  // The face's forward axis (third column) and right axis (first column) in camera space (y up).
  const fx = m[8], fy = m[9], fz = m[10];
  // Landmarks in pixels (z is on x's scale), so distances hold up while the head turns.
  const L = result.faceLandmarks[0], vw = video.videoWidth || 640, vh = video.videoHeight || 480;
  const P = i => [L[i].x * vw, L[i].y * vh, L[i].z * vw];
  const dist = (i, j) => { const a = P(i), c = P(j); return Math.hypot(a[0] - c[0], a[1] - c[1], a[2] - c[2]); };
  const scale = dist(LM.eyeOuterR, LM.eyeOuterL); // eye corner to eye corner: the face's size in the image
  const ear = ([p1, p2, p3, p4, p5, p6]) => (dist(p2, p6) + dist(p3, p5)) / (2 * dist(p1, p4)); // eye aspect ratio
  const along = (i, a, c) => { // where the iris sits between two eye corners, 0..1 from the image's left
    const p = P(i), u = P(a), v = P(c), d = [v[0] - u[0], v[1] - u[1]];
    return ((p[0] - u[0]) * d[0] + (p[1] - u[1]) * d[1]) / (d[0] * d[0] + d[1] * d[1]);
  };
  return {
    b,
    yaw: Math.atan2(fx, fz) * 180 / Math.PI, // + : the face turns towards the camera image's right
    pitch: Math.atan2(-fy, Math.hypot(fx, fz)) * 180 / Math.PI, // + : looking down
    roll: Math.atan2(m[1], m[0]) * 180 / Math.PI, // + : counter-clockwise in the camera image
    tx: m[12], ty: m[13],
    gap: dist(LM.lipTop, LM.lipBottom) / scale, // between the inner lips
    width: dist(LM.mouthR, LM.mouthL) / scale, // corner to corner
    earR: ear(LM.earR), earL: ear(LM.earL),
    irisX: (along(LM.irisR, LM.eyeOuterR, LM.eyeInnerR) + along(LM.irisL, LM.eyeInnerL, LM.eyeOuterL)) / 2, // + : the image's right
  };
}
