// The Soundboard card. Each pad plays a sound into the call and to you, and can bring a mood, a motion and
// cat settings along while it plays; they're undone when it ends (unless the pad says to keep them), and the
// cat mouths along. The call hears it through kitty-cam's "Kitty Cam Sounds" output, which comes out of
// "Kitty Cam Mic" together with your mic (kittycam/audio.py). The files and pads live in kitty-cam's sounds/
// folder (sounds.json); `kitty-cam --play` reaches the page through /events.
import { CatEngine, st } from "./cat.js";
import { levelOf } from "./mic.js";
import { names, presetOf, setMood } from "./moods.js";
import { SETTING_DEFS, setSettings, settings } from "./settings.js";
import { $, store } from "./util.js";

const MOTIONS = { hop: "hop", jolt: "jolt", squish: "squish while it plays" };
const SINK = "Kitty Cam Sounds";
// The settings icon on each pad (drawn, so its size doesn't depend on a font's ⚙).
const GEAR = `<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2"
  stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83
  2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1.08-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2
  2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1.08 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2
  2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2
  2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>`;

let pads = []; // [{file, name, volume, mood, motion, settings, keep, lipsync}], in their order
const buffers = new Map(); // file → its decoded AudioBuffer
const playing = new Map(); // file → {sources, token}
let saveTimer = 0, token = 0, dragFrom = -1; // dragFrom: the slot of the pad being dragged to a new place
const hear = { on: store.get("sounds.hear", true) };
const single = { on: store.get("sounds.single", false) }; // one at a time: a new sound stops the others

// Two outputs: you (the default output; its bus also feeds the lip sync) and the call (Kitty Cam Sounds).
const local = new AudioContext();
const localBus = local.createGain(), hearGain = local.createGain();
export const soundMeter = { analyser: local.createAnalyser(), buf: null, floor: -50, talk: 0 };
soundMeter.analyser.fftSize = 1024;
soundMeter.buf = new Float32Array(soundMeter.analyser.fftSize);
localBus.connect(soundMeter.analyser);
localBus.connect(hearGain).connect(local.destination);
let call = null; // AudioContext on Kitty Cam Sounds, once that output is found

const name = p => p.name || p.file.replace(/\.[^.]+$/, "");
const padOf = file => pads.find(p => p.file === file);

// ── the call's output ──
async function findSink() {
  const out = (await navigator.mediaDevices.enumerateDevices()).find(d => d.kind === "audiooutput" && d.label === SINK);
  if (out && !call) {
    call = new AudioContext({ sinkId: out.deviceId });
  } else if (!out && call) {
    call.close();
    call = null;
  }
  $("sb-note").textContent = call ? "" : "the call doesn't hear these: no Kitty Cam Mic (see kitty-cam's output)";
}

// ── playing ──
// Effects: the state before the first sound with effects, and what the sounds set, undone when the last one ends.
let before = null, applied = {}, appliedMood = null, squishes = 0;

function startEffects(p) {
  const values = { ...(p.mood ? presetOf(p.mood) : {}), ...(p.settings || {}) };
  if (p.keep) { // for good: just like picking them yourself
    if (Object.keys(values).length) setSettings(values);
    if (p.mood) setMood(p.mood, false);
  } else {
    if (!before) before = { settings: { ...settings }, mood: st.expression };
    if (Object.keys(values).length) setSettings(values, false);
    Object.assign(applied, values);
    if (p.mood) setMood(appliedMood = p.mood, false, false);
  }
  if (p.motion === "squish" && squishes++ === 0) CatEngine.press(st, true);
}

function endEffects(p) {
  if (p.motion === "squish" && --squishes === 0) CatEngine.press(st, false);
  if (!before || [...playing.keys()].some(f => !padOf(f)?.keep && f !== p.file)) return; // others still playing
  // Undo only what still holds the sounds' value: a setting you changed meanwhile stays as you set it.
  const back = Object.fromEntries(Object.entries(applied).filter(([k, v]) => settings[k] === v).map(([k]) => [k, before.settings[k]]));
  if (Object.keys(back).length) setSettings(back);
  if (appliedMood && st.expression === appliedMood) setMood(before.mood, false);
  before = null;
  applied = {};
  appliedMood = null;
}

async function load(file) {
  if (!buffers.has(file)) {
    const data = await (await fetch(`sounds/${encodeURIComponent(file)}`)).arrayBuffer();
    buffers.set(file, await local.decodeAudioData(data));
  }
  return buffers.get(file);
}

export async function play(file) {
  const p = padOf(file);
  if (!p) return;
  const buffer = await load(file);
  if (single.on) for (const f of [...playing.keys()]) if (f !== file) stop(f); // their effects end first
  const again = playing.has(file);
  if (again) stopSources(file);
  local.resume();
  const t = ++token, sources = [];
  for (const [ctx, dest] of [[local, localBus], [call, call && call.destination]]) {
    if (!ctx) continue;
    ctx.resume();
    const src = ctx.createBufferSource(), gain = ctx.createGain();
    src.buffer = buffer;
    gain.gain.value = p.volume ?? 1;
    src.connect(gain).connect(dest);
    src.start();
    sources.push(src);
  }
  sources[0].onended = () => { if (playing.get(file)?.token === t) finish(file); };
  playing.set(file, { sources, token: t, lipsync: p.lipsync !== false });
  if (!again) startEffects(p);
  if (p.motion === "hop" || p.motion === "jolt") CatEngine.act(st, p.motion, 1); // again on a restart
  showPlaying(file, buffer.duration);
}

function stopSources(file) {
  for (const s of playing.get(file).sources) { s.onended = null; try { s.stop(); } catch {} }
}

function finish(file) {
  const p = padOf(file) || { file };
  playing.delete(file);
  endEffects(p);
  showPlaying(file, 0);
}

export function stop(file) {
  if (!playing.has(file)) return;
  stopSources(file);
  finish(file);
}

export function stopAll() {
  for (const file of [...playing.keys()]) stop(file);
}

// How much the cat mouths along, 0..1, once per drawn frame: the sounds that lip-sync, as loud as they are.
export function soundLevel(dt) {
  const level = levelOf(soundMeter, dt, false);
  return [...playing.values()].some(p => p.lipsync) ? level : 0;
}

// ── the card ──
function showPlaying(file, duration) {
  const b = [...$("pads").querySelectorAll(".pad")].find(el => el.dataset.file === file);
  if (!b) return;
  b.classList.remove("playing");
  if (duration) {
    b.style.setProperty("--dur", `${duration}s`);
    void b.offsetWidth; // restart the progress bar's animation
    b.classList.add("playing");
  }
}

function summary(p) {
  const s = Object.entries(p.settings || {}).map(([k, v]) => {
    const d = SETTING_DEFS[k];
    return d ? `${d.label.toLowerCase()} ${d.toggle ? (v ? "on" : "off") : d.range ? `${v}%` : d.options[v]}` : "";
  });
  return [p.mood, p.motion, ...s].filter(Boolean).join(" · ") + (p.keep && (p.mood || s.length) ? " (kept)" : "");
}

function renderPads() {
  $("sb-empty").hidden = pads.length > 0;
  $("pads").replaceChildren(...pads.map(padButton));
}

// A pad: the button that plays it, and ⚙ in its corner for its settings (a popup).
function padButton(p, i) {
  const wrap = document.createElement("div");
  wrap.className = "pad-wrap";
  const b = document.createElement("button");
  b.className = "pad";
  b.dataset.file = p.file;
  b.title = `${p.file}${i < 9 ? ` · Shift+${i + 1}` : ""} · click again to restart, right-click to stop`;
  const label = document.createElement("span");
  label.className = "pad-name";
  label.textContent = (i < 9 ? `${i + 1} ` : "") + name(p);
  const fx = document.createElement("small");
  fx.textContent = summary(p);
  b.append(label, fx);
  b.onclick = () => play(p.file);
  b.oncontextmenu = e => { e.preventDefault(); stop(p.file); };
  if (playing.has(p.file)) b.classList.add("playing");
  const gear = document.createElement("button");
  gear.className = "pad-gear";
  gear.innerHTML = GEAR;
  gear.title = `${name(p)}: volume, mood, motion, cat settings`;
  gear.setAttribute("aria-label", gear.title);
  gear.onclick = () => openEditor(p);
  wrap.append(b, gear);
  draggable(wrap, i);
  return wrap;
}

// Drag a pad onto another to put it there: before it on its left half, after it on its right half.
function draggable(wrap, i) {
  wrap.draggable = true;
  const side = e => { const r = wrap.getBoundingClientRect(); return e.clientX > r.left + r.width / 2 ? "after" : "before"; };
  const unmark = () => wrap.classList.remove("drop-before", "drop-after");
  wrap.ondragstart = e => {
    dragFrom = i;
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", pads[i].file);
    wrap.classList.add("dragging");
  };
  wrap.ondragend = () => {
    dragFrom = -1;
    for (const w of $("pads").children) w.classList.remove("dragging", "drop-before", "drop-after");
  };
  wrap.ondragover = e => {
    if (dragFrom < 0 || dragFrom === i) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
    unmark();
    wrap.classList.add(`drop-${side(e)}`);
  };
  wrap.ondragleave = e => { if (!wrap.contains(e.relatedTarget)) unmark(); };
  wrap.ondrop = e => {
    if (dragFrom < 0) return;
    e.preventDefault();
    e.stopPropagation(); // not the card's file drop
    let to = i + (side(e) === "after" ? 1 : 0);
    const [moved] = pads.splice(dragFrom, 1);
    if (dragFrom < to) to--;
    pads.splice(to, 0, moved);
    dragFrom = -1;
    save();
    renderPads();
  };
}

// A row of choice chips; `choices` [[value, text]], `get` the current value, `set` on a click.
function chips(choices, get, set) {
  const row = document.createElement("div");
  row.className = "chips";
  const buttons = choices.map(([value, text]) => {
    const b = document.createElement("button");
    b.textContent = text;
    b.onclick = () => { set(value); show(); };
    return b;
  });
  const show = () => buttons.forEach((b, n) => {
    const on = choices[n][0] === get();
    b.classList.toggle("on", on);
    b.setAttribute("aria-pressed", on);
  });
  show();
  row.append(...buttons);
  return row;
}

function field(label, ...content) {
  const row = document.createElement("div");
  row.className = "setting";
  const l = document.createElement("span");
  l.className = "setting-label";
  l.textContent = label;
  row.append(l, ...content);
  return row;
}

// The pad's settings, in a popup: its name, volume and place, and what it does to the cat. Every change is
// kept at once (sounds.json); the pads show the new summary once it closes.
function openEditor(p) {
  const dlg = $("pad-dialog");
  dlg.replaceChildren(editor(p));
  if (!dlg.open) dlg.showModal();
}

function editor(p) {
  const i = pads.indexOf(p);
  const box = document.createElement("div");
  box.className = "pad-edit";
  const changed = () => save();

  const head = document.createElement("div");
  head.className = "pad-head";
  const title = Object.assign(document.createElement("input"), { value: name(p), placeholder: p.file });
  title.setAttribute("aria-label", "name");
  title.onchange = () => { p.name = title.value.trim() || undefined; changed(); };
  const btn = (text, tip, fn) => {
    const b = document.createElement("button");
    b.textContent = text;
    b.title = tip;
    b.onclick = fn;
    return b;
  };
  const move = d => () => {
    const j = i + d;
    if (j < 0 || j >= pads.length) return;
    [pads[i], pads[j]] = [pads[j], pads[i]];
    changed();
    renderPads();
    openEditor(p); // its new slot number
  };
  const remove = btn("remove", "delete this sound's file", () => {
    if (!remove.classList.contains("confirm")) {
      remove.classList.add("confirm");
      remove.textContent = "really remove?";
      setTimeout(() => { remove.classList.remove("confirm"); remove.textContent = "remove"; }, 3000);
      return;
    }
    stop(p.file);
    $("pad-dialog").close();
    fetch(`sounds/${encodeURIComponent(p.file)}`, { method: "DELETE" }).then(refresh);
  });
  const close = btn("×", "close (Esc)", () => $("pad-dialog").close());
  close.className = "pad-close";
  head.append(`${i + 1}`, title, btn("▶", "play", () => play(p.file)), btn("↑", "earlier", move(-1)), btn("↓", "later", move(1)), close);

  const vol = Object.assign(document.createElement("input"), { type: "range", min: 0, max: 150, step: 5, value: Math.round((p.volume ?? 1) * 100) });
  const volOut = document.createElement("output");
  volOut.textContent = `${vol.value}%`;
  vol.oninput = () => { volOut.textContent = `${vol.value}%`; };
  vol.onchange = () => { p.volume = vol.value / 100; changed(); };
  vol.ondblclick = () => { vol.value = 100; vol.oninput(); vol.onchange(); };
  const volRow = field("Volume", vol, volOut);
  volRow.classList.add("range");

  // The cat settings it brings along: one row per linked setting, its own choices, × to unlink.
  const linked = document.createElement("div");
  const showLinked = () => {
    linked.replaceChildren(...Object.keys(p.settings || {}).filter(k => SETTING_DEFS[k]).map(k => {
      const d = SETTING_DEFS[k];
      const unlink = btn("×", "don't change this", () => { delete p.settings[k]; changed(); showLinked(); });
      if (d.range) {
        const [min, max, step] = d.range;
        const r = Object.assign(document.createElement("input"), { type: "range", min, max, step, value: p.settings[k] });
        const out = document.createElement("output");
        out.textContent = `${r.value}%`;
        r.oninput = () => { out.textContent = `${r.value}%`; };
        r.onchange = () => { p.settings[k] = +r.value; changed(); };
        const row = field(d.label, r, out, unlink);
        row.classList.add("range");
        return row;
      }
      const choices = d.toggle ? [[true, "on"], [false, "off"]] : Object.entries(d.options);
      const line = document.createElement("div");
      line.className = "linked";
      line.append(chips(choices, () => p.settings[k], v => { p.settings[k] = v; changed(); }), unlink);
      return field(d.label, line);
    }));
    add.replaceChildren(new Option("+ change a cat setting…", ""), ...Object.values(SETTING_DEFS)
      .filter(d => !(d.id in (p.settings || {}))).map(d => new Option(d.label, d.id)));
  };
  const add = document.createElement("select");
  add.onchange = () => {
    const d = SETTING_DEFS[add.value];
    if (!d) return;
    p.settings = { ...(p.settings || {}), [d.id]: d.toggle ? !settings[d.id] : settings[d.id] };
    changed();
    showLinked();
  };
  showLinked();

  box.append(head, volRow,
    field("Mood", chips([[undefined, "none"], ...names.map(n => [n, n])], () => p.mood, v => { p.mood = v; changed(); })),
    field("Motion", chips([[undefined, "none"], ...Object.entries(MOTIONS)], () => p.motion, v => { p.motion = v; changed(); })),
    field("Cat settings", linked, add),
    field("Afterwards", chips([[false, "undo the mood and settings"], [true, "keep them"]], () => !!p.keep, v => { p.keep = v; changed(); })),
    field("Cat mouths along", chips([[true, "on"], [false, "off"]], () => p.lipsync !== false, v => { p.lipsync = v; changed(); })));
  const foot = document.createElement("div");
  foot.className = "pad-foot";
  foot.append(remove, btn("done", "close (Esc)", () => $("pad-dialog").close()));
  box.append(foot);
  return box;
}

// Keep the pads (order, names, volumes, effects) in sounds.json, a moment after the last change.
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => fetch("sounds.json", { method: "PUT", body: JSON.stringify({ pads }) }), 400);
}

async function refresh() {
  const data = await (await fetch("sounds")).json();
  pads = data.pads;
  for (const f of buffers.keys()) if (!padOf(f)) buffers.delete(f);
  renderPads();
}

async function upload(fileList) {
  // Copied at once: the picker's list empties when it's reset, and a drop's once the drop event is over.
  const files = [...fileList];
  for (const f of files) {
    const r = await fetch(`sounds/${encodeURIComponent(f.name)}`, { method: "POST", body: f });
    if (!r.ok) $("sb-note").textContent = `${f.name}: ${await r.text()}`;
  }
  refresh();
}

export function initSounds() {
  const card = $("soundboard");
  card.addEventListener("dragover", e => { if (e.dataTransfer.types.includes("Files")) { e.preventDefault(); card.classList.add("drop"); } });
  card.addEventListener("dragleave", e => { if (!card.contains(e.relatedTarget)) card.classList.remove("drop"); });
  card.addEventListener("drop", e => {
    e.preventDefault();
    card.classList.remove("drop");
    if (dragFrom < 0) upload(e.dataTransfer.files); // a pad let go beside the others: nothing to add
  });
  $("sb-add").onclick = () => $("sb-file").click();
  $("sb-file").onchange = e => { upload(e.target.files); e.target.value = ""; };
  $("sb-stop").onclick = stopAll;
  const dlg = $("pad-dialog");
  dlg.addEventListener("close", renderPads); // the summaries
  dlg.addEventListener("click", e => { if (e.target === dlg) dlg.close(); }); // a click outside it
  const hearBtn = $("sb-hear");
  const syncHear = () => { hearGain.gain.value = hear.on ? 1 : 0; hearBtn.classList.toggle("on", hear.on); };
  hearBtn.onclick = () => { hear.on = !hear.on; store.set("sounds.hear", hear.on); syncHear(); };
  syncHear();
  const singleBtn = $("sb-single");
  const syncSingle = () => singleBtn.classList.toggle("on", single.on);
  singleBtn.onclick = () => { single.on = !single.on; store.set("sounds.single", single.on); syncSingle(); };
  syncSingle();
  navigator.mediaDevices.addEventListener("devicechange", findSink);
  findSink();
  refresh();
  // `kitty-cam --play` (key bindings), through the server; EventSource reconnects by itself.
  new EventSource("events").onmessage = e => {
    if (e.data === "stop") stopAll();
    else if (e.data.startsWith("play ")) play(e.data.slice(5));
  };
}

// Shift+1–9 (by key position, as Shift changes the character), from main.js's keys.
export const playSlot = i => pads[i] && play(pads[i].file);
