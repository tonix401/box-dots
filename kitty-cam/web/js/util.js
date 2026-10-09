// Small helpers shared by the page's modules.
export const $ = id => document.getElementById(id);
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const smooth = u => { u = clamp(u, 0, 1); return u * u * (3 - 2 * u); };

// Settings, calibration and choices, kept per browser profile (localStorage, "kitty-cam.*").
export const store = {
  get(k, d) { try { const v = localStorage.getItem("kitty-cam." + k); return v === null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem("kitty-cam." + k, JSON.stringify(v)); } catch {} },
};

// A failure, shown in the note `el` (and the console).
export const failed = (what, el) => e => {
  console.error(`kitty-cam: ${what}`, e);
  $(el).textContent = `${what}: ${e.message || e}`;
  $(el).classList.add("bad");
};
