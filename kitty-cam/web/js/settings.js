// The cat settings: three groups of plain choices and switches, the look (what the rig offers), what tracking
// follows, and behaviour. How strongly the cat follows you comes from the calibration, not from here. Saved in
// localStorage (kitty-cam.settings); the moods are presets for the look.
import { RIG, st } from "./cat.js";
import { $, store } from "./util.js";

const SETTINGS = [
  ["Look", [
    { id: "eyes", label: "Eyes", options: { sparkle: "sparkly", open: "round", wide: "wide", stars: "✦", squint: "> <", closed: "‿ ‿", x: "× ×", shades: "shades" }, def: "sparkle",
      title: "only round, wide and sparkly eyes can blink (shades: sunglasses over closed eyes)" },
    { id: "mouth", label: "Mouth when closed", options: { talk: "talking", cat: "ω", smile: "smile", open: "o", none: "none" }, def: "talk",
      title: "what shows while your lips are closed; the talking mouth takes over when you open them" },
    { id: "body", label: "Body", options: { slim: "slim", fat: "chubby" }, def: "slim" },
    { id: "cheeks", label: "Blush", options: { auto: "when smiling", always: "always", never: "never" }, def: "auto" },
    { id: "bow", label: "Bow tie", toggle: true, def: true },
    { id: "whiskers", label: "Whiskers", toggle: true, def: true },
  ]],
  ["Tracking", [
    { id: "trackHead", label: "Head", toggle: true, def: true, title: "turning, tilting and leaning; off: the cat tilts its head now and then by itself" },
    { id: "trackBlinks", label: "Blinks", toggle: true, def: true, title: "off: the cat blinks by itself" },
    { id: "trackGaze", label: "Gaze", toggle: true, def: true, title: "the eyes follow where you look" },
    { id: "trackMouth", label: "Mouth", toggle: true, def: true, title: "opening and the vowel shapes, from your lips" },
    { id: "ears", label: "Ears follow brows", toggle: true, def: true, title: "raised brows perk the ears, a frown flattens them" },
    { id: "mic", label: "Mic lip sync", toggle: true, def: true, title: "your voice opens the mouth too (off if the mic hears the call)" },
  ]],
  ["Behaviour", [
    { id: "mirror", label: "Mirror", toggle: true, def: store.get("mirror", true), title: "on: the cat moves like your reflection" },
    { id: "blinkSync", label: "Blink together", toggle: true, def: true, title: "off: each eye on its own, so winks show" },
    { id: "idle", label: "Idle animation", toggle: true, def: true, title: "breathing, and blinks, twitches and head tilts while no face is tracked" },
  ]],
];
const SETTING_DEFS = Object.fromEntries(SETTINGS.flatMap(([, items]) => items.map(i => [i.id, i])));

export const settings = Object.fromEntries(Object.values(SETTING_DEFS).map(i => [i.id, i.def]));
Object.assign(settings, Object.fromEntries(Object.entries(store.get("settings", {})).filter(([k]) => k in SETTING_DEFS)));

// The view options outside the cat settings: mirroring (a setting), the fill behind the lines (remembered)
// and the camera preview (not).
export const opts = { get mirror() { return settings.mirror; }, fill: store.get("fill", false), preview: false };

// The moods as the rig defines them, before the look below is written into them.
export const ORIG_EXPRESSIONS = JSON.parse(JSON.stringify(RIG.expressions));
export const hiddenParts = new Set();

export function applySettings() {
  // The look wins over every mood's own: the engine reads these expressions live, and the moods keep
  // only their extras (motions, ear positions, the zzz, the sweat drop, sleepy's half-closed eyes).
  for (const name in RIG.expressions) {
    const e = RIG.expressions[name], o = ORIG_EXPRESSIONS[name];
    // Shades aren't an eye variant but a part over the eyes: closed eyes behind them (no blinks to show through).
    e.variants["eye-l"] = e.variants["eye-r"] = settings.eyes === "shades" ? "closed" : settings.eyes;
    e.variants.mouth = settings.mouth === "talk" ? "cat" : settings.mouth; // talking: ω while no face is tracked
    e.variants.body = settings.body;
    e.show = o.show.filter(p => p !== "cheeks" && p !== "shades").concat(settings.cheeks === "always" ? ["cheeks"] : [],
      settings.eyes === "shades" ? ["shades"] : []);
  }
  st.restMouth = settings.mouth !== "talk";
  st.idle = settings.idle;
  st.trackBlink = settings.trackBlinks;
  st.trackHead = settings.trackHead;
  hiddenParts.clear();
  if (!settings.bow) hiddenParts.add("bow");
  if (!settings.whiskers) { hiddenParts.add("whiskers-l"); hiddenParts.add("whiskers-r"); }
  if (settings.cheeks === "never") hiddenParts.add("cheeks");
  $("cam").classList.toggle("unmirrored", !settings.mirror);
}

// Change several settings at once (a mood's preset), or all back to their defaults.
export function setSettings(values) {
  Object.assign(settings, values);
  store.set("settings", settings);
  applySettings();
  renderSettings();
}
export const defaultSettings = () => Object.fromEntries(Object.values(SETTING_DEFS).map(i => [i.id, i.def]));

export function renderSettings() {
  $("settings").replaceChildren(...SETTINGS.map(([group, items]) => {
    const panel = document.createElement("div");
    const h = document.createElement("h3");
    h.textContent = group;
    panel.append(h, ...items.map(i => {
      const row = document.createElement("div");
      row.className = i.toggle ? "setting switch" : "setting";
      if (i.title) row.title = i.title;
      const label = document.createElement("span");
      label.className = "setting-label";
      label.textContent = i.label;
      const chips = document.createElement("div");
      chips.className = "chips";
      chips.setAttribute("role", "group");
      chips.setAttribute("aria-label", `${group}: ${i.label}`);
      const choices = i.toggle ? [[true, "on"], [false, "off"]] : Object.entries(i.options);
      const buttons = choices.map(([value, text]) => {
        const b = document.createElement("button");
        b.textContent = text;
        b.onclick = () => {
          settings[i.id] = value;
          store.set("settings", settings);
          applySettings();
          show();
        };
        return b;
      });
      const show = () => buttons.forEach((b, n) => {
        const on = choices[n][0] === settings[i.id];
        b.classList.toggle("on", on);
        b.setAttribute("aria-pressed", on);
      });
      show();
      chips.append(...buttons);
      row.append(label, chips);
      return row;
    }));
    return panel;
  }));
}
