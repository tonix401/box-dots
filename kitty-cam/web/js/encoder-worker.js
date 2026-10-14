// Frames to kitty-cam, off the main thread (there they'd queue behind face detection). Each frame goes out
// as the camera's own format, YUV 4:2:0 (BT.601, limited range like webcams), which kitty-cam writes to the
// device untouched. That replaced JPEG + ffmpeg, which held every frame ~100 ms.
// In: {bmp, stats, drawn}. Out: "ok" (on the camera), "none" (kitty-cam has no camera), "down", "error".
let canvas, ctx, out;

onmessage = async e => {
  const { bmp, stats, drawn } = e.data;
  const w = bmp.width, h = bmp.height;
  if (!canvas) {
    canvas = new OffscreenCanvas(w, h);
    ctx = canvas.getContext("2d", { willReadFrequently: true });
    out = new Uint8Array(w * h * 3 / 2);
  }
  ctx.drawImage(bmp, 0, 0);
  bmp.close();
  const px = ctx.getImageData(0, 0, w, h).data, uAt = w * h, vAt = uAt + uAt / 4;
  for (let i = 0, n = w * h; i < n; i++) {
    const r = px[4 * i], g = px[4 * i + 1], b = px[4 * i + 2];
    out[i] = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
  }
  for (let y = 0; y < h; y += 2) for (let x = 0; x < w; x += 2) { // colour per 2×2 block, from its sum
    const a = 4 * (y * w + x), c = a + 4 * w;
    const r = px[a] + px[a + 4] + px[c] + px[c + 4], g = px[a + 1] + px[a + 5] + px[c + 1] + px[c + 5], b = px[a + 2] + px[a + 6] + px[c + 2] + px[c + 6];
    const k = (y >> 1) * (w >> 1) + (x >> 1);
    out[uAt + k] = ((-38 * r - 74 * g + 112 * b + 512) >> 10) + 128;
    out[vAt + k] = ((112 * r - 94 * g - 18 * b + 512) >> 10) + 128;
  }
  let state = "down";
  try {
    const r = await fetch("/frame", { method: "POST", body: out, headers: { "X-Kitty-Stats": stats, "X-Kitty-Drawn": String(drawn) } });
    state = r.status === 204 ? "ok" : r.status === 503 ? "none" : "error";
  } catch (err) {}
  postMessage(state);
};
