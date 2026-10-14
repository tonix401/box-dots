// Sending the drawn frames to kitty-cam through the encoder worker, one in flight at a time.
const encoder = new Worker("js/encoder-worker.js");

// How it's going: the last answer ("ok", "none", "down", "error"; "" before the first) and frames sent
// since the status bar last read and reset `sent`.
export const output = { state: "", sent: 0 };
let sending = false;

encoder.onmessage = e => {
  output.state = e.data;
  if (e.data === "ok") output.sent++;
  sending = false;
};

// Send the canvas as it is now, unless the previous frame is still on its way. `stats`: the page's figures
// for kitty-cam's /status (JSON).
export function send(canvas, stats) {
  if (sending) return;
  sending = true;
  const drawn = Date.now();
  createImageBitmap(canvas).then(bmp => encoder.postMessage({ bmp, stats, drawn }, [bmp]), () => { sending = false; });
}
