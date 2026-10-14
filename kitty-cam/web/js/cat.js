// The cat: its rig and the engine's state for it. Both files in cat/ are published here by the cat's own
// build (~/.config/cat/build.py); cat/engine.js is a classic script (Quickshell's QML runs it too) that
// defines the global CatEngine.
export const CatEngine = globalThis.CatEngine;
export const RIG = await (await fetch("cat/rig.json")).json();
export const st = CatEngine.create(RIG, "neutral");
