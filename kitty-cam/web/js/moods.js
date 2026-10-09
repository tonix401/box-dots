// The moods (the rig's expressions). Each is a preset: picking it sets the look (eyes, mouth, body, blush) to
// the mood's own, which you can then change in the settings, and plays the mood for its extras (happy's hop,
// purr's flattened ears, asleep's zzz, straining's sweat drop and tremble, …).
import { CatEngine, RIG, st } from "./cat.js";
import { ORIG_EXPRESSIONS, defaultSettings, setSettings } from "./settings.js";
import { $, store } from "./util.js";

export const names = Object.keys(RIG.expressions); // keys 1–9 pick the first nine

function presetOf(name) {
  const o = ORIG_EXPRESSIONS[name];
  return {
    eyes: o.show.includes("shades") ? "shades" : o.variants["eye-l"],
    mouth: name === "neutral" ? "talk" : o.variants.mouth,
    body: o.variants.body,
    cheeks: o.show.includes("cheeks") ? "always" : "auto",
  };
}

export function setMood(name, preset = true) {
  store.set("mood", name);
  if (preset) setSettings(presetOf(name));
  CatEngine.setExpression(st, name);
  for (const b of $("exprs").children) b.classList.toggle("on", b.dataset.name === name);
}

export function initMoods() {
  $("exprs").replaceChildren(...names.map((name, i) => {
    const b = document.createElement("button");
    b.dataset.name = name;
    b.textContent = i < 9 ? `${i + 1} ${name}` : name;
    b.onclick = () => setMood(name);
    return b;
  }));
  $("settings-reset").onclick = () => {
    setSettings(defaultSettings());
    setMood("neutral", false);
  };
  const saved = store.get("mood", "neutral");
  setMood(RIG.expressions[saved] ? saved : "neutral", false);
}
