# Cat avatar rig

The terminal-pet cat as one rigged, animatable drawing. Both hand-drawn cats (`cat.svg`, `fat-cat.svg`)
are poses of this rig: they share the head, ears, whiskers and bow tie and differ only in eyes,
mouth and body.

| File | |
|---|---|
| `rig.svg` | **Source of truth.** Edit in Inkscape or by hand; strokes are `currentColor` |
| `poses.json` | **Source.** Expressions, plus the two exported terminal poses |
| `engine.js` | **Source.** The animation engine: rig.json in, a frame of matrices/paths/opacities out. Plain ES2017 (no `?.`/`??`) so QML runs it too |
| `build.py` | Validates the sources, writes everything below. `--check` validates only; `--still EXPR` prints a static SVG (reference renderer) |
| `model3d.py` | The 3D head: inflates the outline into a solid and meshes it, for `build.py` (see "The 3D head"; needs numpy) |
| `rig.json` | Generated manifest for renderers |
| `preview.html` | Browser renderer + tuning panel (expressions, motions, shape-key sliders; hold the mouse on the cat to squish it). Carries its own copies of `rig.json` and `engine.js`; `?expr=startled&idle=0` |
| `~/.config/quickshell/components/CatEngine.js` | Generated copy of `engine.js` for Cat.qml |
| `../kitty-cam/web/cat/` | Kitty Cam's copies of `rig.json` and `engine.js` (see "Kitty Cam") |
| `voice.py` | The sing-along analyser Pet.qml runs: listens to the speakers while something plays, prints mouth shapes (see "Singing") |
| `build.py --export cat\|fat-cat` | The two original drawings on demand, path data verbatim (`--color '#hex'`, else matugen's color tag). They used to be matugen templates rendered for the kitty greeting; since 2026-10-07 nothing renders them |

Renderers: `~/.config/quickshell/components/Cat.qml` (used by `KittyCat.qml`, a cat in the top right
corner of every kitty window, driven by `Pet.qml`), `preview.html` (SVG) and Kitty Cam's page (Canvas 2D).
Both only draw what `engine.js` returns, so they animate identically.
After editing a source, run `./build.py`; the cats reload `rig.json` by themselves.

## rig.svg

- `<g id="rig" transform="translate(x,y)">` wraps everything. Part coordinates are *inside* it;
  only the exports apply the translate. Renderers work in part coordinates throughout.
- A **part** is `<g id="name" data-pivot="x y">`. Parts nest; a child moves with its parent.
  `display="none"` on a part hides it by default (an expression can `show` it).
- A part holds either paths directly or **variants**, `<g data-variant="name">`, of which one is
  drawn at a time (the first is the default).
- A **shape key** is `<g data-key="name" display="none">` inside a part without variants: the
  part's paths again, in the same order and with the same segment structure, moved. Renderers blend
  `base + Σ weight·(key − base)` point by point. Keep shared endpoints where they are, so a keyed
  part stays joined to its neighbours (the ear keys only move the outline's control points).
- A **hinge key**, `<g data-key="name" data-tip="degrees scale" />` (empty), is computed by `build.py`
  for a flap like an ear: the part's first path keeps its endpoints (where it meets the head), its tip
  (the curve point farthest from the line between them) turns `degrees` about their midpoint (positive is
  clockwise on screen) and moves to `scale` of its distance, and the one affine map that fixes the two
  endpoints and moves the tip there is applied to **every** path of the part. The outline and the inner
  ear move as one piece, stay joined to the head, and stay consistent at every blend weight.
- `data-chain="c" data-chain-index="n"` marks paths that were one path in the original drawing.
  The exports join them back (and check they meet); renderers draw them separately.
- `data-skin="bone" data-skin-y="y0 y1"` on a top-level part **skins** it to another part: every point
  blends between its own part's world matrix and the bone's, with weight 1 at y ≤ y0, 0 at y ≥ y1 and a
  smoothstep between. The body is skinned to the head, so its top follows the head (tilts, bobs, lag)
  while the feet stay planted: the neck never comes apart.
- `data-depth="d"` on the head makes it a **real 3D solid**, d deep (see "The 3D head"). Its parts say how
  they sit on it: `data-lift="z"` raises a part z above the skin, `data-billboard="z"` keeps it flat and
  facing the viewer, z in front of the skin anywhere under it (it only moves, never deforms),
  `data-sweep="k"` sweeps it back by k per unit of length beyond the outline (whiskers).
- `class`: `line` = miter joins, `line-join` / `ear` = round joins, `filled` = filled with the stroke
  color, `solid` = filled, no stroke, `blush` = fill at 35 % opacity, `hole` = cut out of the filled
  shape just before it (even-odd; the eye highlights).

### Parts (paint order)

| Part | Parent | Pivot | Variants / keys |
|---|---|---|---|
| `body` | – | feet centre | `slim` (cat.svg), `fat` (fat-cat.svg); skinned to `head` over y 98–132. The slim body's right side was redrawn on 2026-10-08 as the left side mirrored about x = 74.61, midway between the neck ends (the original kinked near the top and clipped into the cheek when the head turned right), so the `cat` export no longer matches cat.svg there |
| `head` | – | chin | outline (cheeks + crown) |
| `bow` | head | bow centre | |
| `ear-l`, `ear-r` | head | ear base midpoint | hinge keys `twitch` (tip 14° out), `flat` (tip 50° out and down to 74 %), `perk` (tip 10° up, 108 %) |
| `whiskers-l`, `whiskers-r` | head | where they meet the cheek | |
| `eye-l`, `eye-r` | head | the eye's centre | `open`, `sparkle` (bigger, with highlights), `squint` (`> <`), `closed` (`‿ ‿`), `x` (`× ×`), `stars` (`✦ ✦`), `wide` (rings + pupils, unused). Two parts (since 2026-10-07) so a tracked face can wink; poses.json's `"eyes"` sets both |
| `shades` | head | between the eyes | hidden by default; sunglasses over the eyes (solid lenses with cut-out glints) |
| `cheeks` | head | | hidden by default; blush |
| `sweat` | head | | hidden by default; a drop at the right temple |
| `mouth` | head | mouth | `smile` (cat.svg), `cat` (`ω`), `none`, `open` |
| `sing` | head | mouth | hidden by default; the singing mouth, a closed smile with shape keys `open` ("ah"), `wide` ("ee"), `round` ("oo"). Shown instead of `mouth` while singing |

| `zzz` | – | | hidden by default; three z's |

On the 3D head, the mouth and the sing mouth are lifted 1.5 above the skin, the shades 3 (they follow the eyes
round the face), the bow tie is a billboard 6 in front of the chin, and the whiskers sweep back 2 per unit of
length beyond the outline; everything else lies on the skin.

## rig.json

```
{ version, viewBox, origin,            // the exports' viewBox and translate
  canvas: [x, y, w, h],                // part coordinates covering every variant and key, plus margin
  stroke: {width: 2, cap: "round"},
  order: [part, ...],                  // paint order; parents come before their children
  parts: { name: { parent, pivot: [x, y], hidden,
                   variants: { name: [ {paths: [{pts, closed}], stroke, fill, alpha, join, evenodd, d} ] },
                   keys: { name: [ [pts per subpath] per shape ] },         // matches the "default" variant
                   skin: null | {bone, weights: {variant: [ [ [w per point] per subpath ] per shape ]}},
                   solid: null | {lift, billboard?, sweep?},               // the head's parts, on the 3D head
                   keyAffines: {key: [a, b, c, d, e, f]} } },              // hinge keys as matrices (ears)
  expressions: { name: { variants: {part: variant}, keys: {"part.key": w},
                         transforms: {part: {tx, ty, sx, sy, rot}}, show: [part], motion, breath } },
  model: null | { centre: [x, y], depth, outline: n,                // the 3D head (model3d.py)
                  verts: [x, y, z, …], normals: [x, y, z, …], tris: [a, b, c, …], tags: [tag per vertex],
                  height: {x0, y0, w, h, values} } }               // its depth per rig unit (−distance outside)
```

A shape on a `data-chain` also carries `chain` (the head's outline: the 3D head draws it as its silhouette).
`pts` is `[P0, C1, C2, P1, C1, C2, P2, …]`: every path is absolute cubic Béziers only (lines are
converted), so blending is a plain point-wise lerp. A shape's first subpath is its outline, the
rest are holes. `d` is the whole shape as an SVG string.

**Transforms.** A part's local matrix is
`translate(pivot + (tx, ty)) · rotate(rot°) · scale(sx, sy) · translate(−pivot)`, and its world
matrix is `parent world · local`. `rot` is in degrees, clockwise on screen (y points down).

## Expressions (poses.json)

`"eyes"` in an expression's `variants` or `transforms` is shorthand for both `eye-l` and `eye-r`
(build.py expands it; rig.json only has the two parts).

| | Eyes | Mouth | Body | Keys / transforms / shown | Motion |
|---|---|---|---|---|---|
| `neutral` | sparkle | cat | slim | | |
| `happy` | squint | cat | slim | cheeks | `hop` on entry |
| `purr` | squint | cat | slim | ears `flat` 0.3, cheeks | |
| `vibing` | sparkle | cat | slim | cheeks | `bob` while held |
| `sleepy` | open | none | slim | ears `flat` 0.3, eyes `sy` 0.35 | a yawn every 20–45 s (idle loop) |
| `asleep` | closed | cat | fat | ears `flat` 0.5, zzz, cheeks | breath every 6 s |
| `impressed` | stars | open | slim | ears `perk` 1, cheeks | `jolt` on entry |
| `straining` | squint | none | slim | sweat drop | `tremble` while held (whole cat ±0.5 at 13 Hz) |
| `startled` | x | open | slim | | `jolt` on entry |
| `cool` | closed (under the shades) | smile | slim | ears `perk` 0.4, shades; KittyCat draws it red (`#ff4d4d`) | |

`"sing": true` (neutral, happy, purr, vibing, cool) lets an expression sing along; the others keep their mouth.

`exports.cat` / `exports["fat-cat"]` are the poses of the two original drawings (`build.py --export`).

## Animation (engine.js, each frame)

1. **Ease** every part's transform, key weights and visibility towards the expression's (settling in
   ~0.22 s); variant opacities crossfade (~0.12 s). `v = goal + (v − goal)·e^(−4.6·dt/settle)`.
2. **Idle loop** on top:
   - blink: eyes `sy` × (1 → 0.1 → 1) over 0.16 s (0.5 s sleepy), every 3–7 s, 15 % double; `open`/`sparkle`/`wide` eyes only
   - ear twitch: one ear's `twitch` += |sin 2πp| over 0.36 s, every 8–20 s, its whiskers turning ±3°
   - head tilt: every 9–22 s the head tilts 7° one way for 1.8 s (through the tilt spring, so it overshoots)
   - yawn (`sleepy` only): 4–10 s after the cat gets sleepy, then every 20–45 s, y rises over 0.78 s
     (smoothstep), holds (stretching to 1.06) until 1.77 s, falls by 2.6 s: the `sing` mouth shows
     (opacity min(1, 3y)) with keys `open` 1.5, `wide` 0.8, `round` 0.3 at y = 1, eyes `sy` × (1 − 0.8 y),
     ears `flat` += 0.5 y, head `ty` −= 2 y, whole cat `sy` × (1 + 0.05 y), `sx` × (1 − 0.025 y).
     Fades out over ~0.25 s if the expression changes mid-yawn; a tracked face suppresses it
   - breathing, b = (1 − cos 2πt/breath)/2: body `sy` × (1 + 0.025 b), `sx` × (1 + 0.015 b), head `ty` −= 1.3 b
3. **Whole-cat motion** about the feet (75, 138), with squash and stretch:
   - `hop` (0.55 s each): crouch (to `sy` 0.86, `sx` 1.1) → jump 13 up, stretched on the way up → land squashed (`sy` 0.85)
   - `jolt` (0.32 s): stretch up (`sy` 1 + 0.12h) and 5 up
   - `bob` (while held): drives the tilt spring with 4 sin(2πt/0.9), head `ty` −= 1.2|…|
4. **Springs** (damped, stepped at ≤ 8 ms) give the squish:
   - head lag (k 220, c 11): pushed by −0.25 × the body's vertical acceleration, so the head sinks on
     take-off and wobbles after landing; added to the head's `ty`, clamped to ±6
   - tilt (k 140, c 9): the head's extra rotation
   - squash (k 320, c 9): goal −0.2 while pressed, else 0; the whole cat `sy` × (1 + s), `sx` × (1 − 0.7 s).
     Underdamped, so letting go boings
5. **Skinning**: the body's points blend between the body's and the head's world matrices by their weights.
6. `zzz`: the z's fade in and out in turn on a 3.6 s cycle.
7. **Face tracking** (`track(st, pose | null)`, used by Kitty Cam; `st.restMouth`: see Kitty Cam → Cat settings): `tracked` eases 0 ↔ 1 (~0.25 s)
   as a face is found or lost, and scales everything here. The face replaces the idle blinks, twitches
   and tilts; breathing, motions and springs stay. Head: `rot += roll`, leans by `x`/`y`.
   **The head turns in 3D** (see "The 3D head"): yaw ±1 is 30°, pitch ±1 20°. Each eye closes with its own lid (`sy × (1 − 0.9 blink)`, blinkable variants only) and
   shifts with the gaze (±1.5). The ears are the eyebrows (`brow` > 0 → `perk`, < 0 → `flat`). The sing
   mouth shows and follows the pose's `open`/`wide`/`round`; the cheeks blush at least by `smile`.
8. **Singing** (`voice(st, [active, open, wide, round])`): in an expression with `sing`, while `active`,
   the `sing` mouth fades in over `mouth` (~0.12 s) and its keys follow `open`/`wide`/`round` (~0.05 s);
   the head lifts by up to 0.8 as the mouth opens.

## The 3D head (model3d.py, engine.js)

Unturned, the cat is the drawing, drawn as it is. When a tracked face turns or nods the head, the head is a real
3D solid made from the drawing, and every line of it is drawn from that solid.

**The solid** (`model3d.py`, run by `build.py`; needs numpy): the head's outline, ears included (the chain
`outline`), closed across the neck, is inflated: the depth over each point is `√h`, where `h` solves the Poisson
equation `Δh = −4` inside the outline with `h = 0` on it (on a 0.5-unit grid, by over-relaxation). That is an exact
hemisphere over a disk and a round cross-section everywhere, so narrower parts come out thinner: the ears are soft
lobes, like a plush toy's. It's scaled to `data-depth` at its deepest and mirrored, front and back. The mesh: the
outline every 2 units, rings of points 0.4, 1.2 and 2.4 inside it (the surface is steepest there; points where a
ring folds over at a sharp corner are dropped), a 3.5-unit grid inside, all triangulated (Delaunay) and kept inside
the outline; the inside points get a front and a back copy, the outline is shared. Vertex normals are averaged from
the faces. Tags: the ears' vertices (everything on an ear's side of the line where it meets the head) bend with the
ears' shape keys, which are affine maps keeping that line in place, so the mesh bends seamlessly; a band along the
neck draws no silhouette where it faces down. `height` is the depth on a 1-unit grid (minus the distance outside the
outline) for the drawn parts. Everything turns about the solid's centroid.

**Each turned frame** (`engine.js`, pass 2; ~2 ms in a browser):
1. The mesh's vertices: the ears' bent by their keys, then turned (the nod first, about the head's own sideways
   axis, then the turn about the neck's vertical one) and projected straight on.
2. Depth: the faces turned towards the viewer are filed by 3-unit cells of the screen; a point's visibility is
   decided against the exact depth of the faces over it (within 0.5).
3. Silhouette: where the vertex normals' dot with the view direction changes sign along an edge, linked across
   each triangle; the solid is closed, so these are loops. Each point is tested a unit outside itself (along its
   outward normal), so its own fold can't hide it but anything in front still does. Along the neck it's skipped
   where it faces down (the body goes on there). Visible stretches shorter than 3.5 are dropped; the rest are
   resampled every 1.5, smoothed and drawn as the head's first shape (the others, and the ears' outer curves,
   are empty). The longest loop, closed, is `frame.outline`, for a renderer's fill.
4. The head's parts: every curve sampled (10 points a segment), each sample given the depth of where it is at
   rest (`height`, plus its `lift`; a billboard's own depth; past the outline, `sweep` back), turned, and kept
   where it's visible. A filled or closed shape (eyes, the inner ear) shows whole if at least 60 % is visible,
   else not at all; open lines show their visible stretches. A billboard only moves with its pivot.
5. The neck (the body's skin bone) follows the solid's rim: the head's matrix times the turned plane of depth 0.

All of it is in the head's space (`worlds[part]` = the head's matrix), so roll, lean and the springs apply on top.
At yaw = pitch = 0 none of it runs, and the frames are exactly the drawing's (the terminal cats never turn).

## Behaviour (Quickshell: Pet.qml)

Base mood, highest first: `asleep` (no input for 5 min, `IdleMonitor`), `vibing` (an MPRIS player
is playing), `sleepy` (23:00–07:00), `neutral`. Reactions override it for a moment, either on every
cat or only on the cat of one window:

| Event | Expression | For | Where | From |
|---|---|---|---|---|
| `error` | startled | 1.5 s | the window it ran in | fish: a command failed (not Ctrl-C) |
| `ok` | happy | 2 s | the window it ran in | fish: a command over 10 s succeeded |
| `impressed` | impressed | 3.5 s | the window it ran in | fish: `fastfetch` or `ff` succeeded (checked before `ok`) |
| `cheer` | happy + 2 hops | 3 s | every cat | a habit check-in or completed todo |
| `wake` | startled | 1 s | every cat | input after being idle |
| `pet` | purr | 2 s | chosen in CatTester | CatTester only (the terminal cats are click-through) |

**Busy:** while a command runs in a kitty window (anything but interactive programs: nvim, less, man,
fzf, htop/btop, claude, tmux, … in any part of a pipeline, and shells/REPLs started bare), that
window's cat is squished flat and `straining` until the command finishes, then boings back — with the
command's reaction, if any. A squish lasts exactly as long as the command (no minimum). The fish
hook sends `busyPid <pid> <id>` before and `finishedPid <pid> <id> <event|none>` after each command; the
per-command id makes the two racing calls safe (a `busy` after its `finished` is ignored).
Aliases are expanded first (`mre` is `ssh tom@mre`), so an alias counts as what it runs.

**Remote:** an ssh or mosh session (`ssh`, `mosh`, `kitten ssh`, or an alias for one) doesn't squish the
cat: the hook sends `remotePid <pid> <id>` instead of `busyPid`, and that window's cat is `cool`, red
with sunglasses, until the same `finishedPid`.

**Singing:** while audio plays, every cat sings along in the expressions that sing. `voice.py`
records the default sink's monitor (only while a playback stream is uncorked, followed with
`pactl subscribe`), takes the centre of the stereo image minus the sides (vocals are mixed centre),
150–4000 Hz, and per 16 ms frame prints `active open wide round`: loudness against the loudest recent
frame (fading ~8 dB/s) opens the mouth, weighed by periodicity (a pitch: a voice, not drums); the
formant bands pick the vowel (high band strong against mid: "ee"; mid weak against low: "oo"; else
"ah"). Lines are held back by the sink's PipeWire latency (~145 ms on the Bluetooth headset) so the
mouth moves when the sound is heard. `qs ipc call cat sing` toggles it, `singOffset <ms>` shifts it
(negative: earlier). `voice.py --debug` prints the features to stderr.

One cat shows: its window's reaction, else an every-cat reaction, else `cool` during an ssh session, else `straining` while busy, else
the pin, else the base mood.
A reaction for every cat replaces any per-window ones. The fish hook sends kitty's `$KITTY_PID`;
each kitty window is its own process, so Quickshell finds the window by its Hyprland `pid` (if
several share one, the focused one).

`qs ipc call cat react <event>` (every cat), `qs ipc call cat reactPid <event> <pid>` (the window of
that process), `busyPid <pid> <id>` / `remotePid <pid> <id>` / `finishedPid <pid> <id> <event|none>` (the squish, or the shades, around a command), `qs ipc call cat mood <expression>` (pins it in place of the base mood; reactions still
play over it), `qs ipc call cat unpin`, `qs ipc call cat tester` or **SUPER + SHIFT + C** (the CatTester panel; its "only …"
toggle aims reactions at the focused window), `qs ipc call cat kitty` (hide/show the cats), `qs ipc call cat sing` / `singOffset <ms>` (singing along).

## Kitty Cam

The cat as a webcam for video calls lives in its own folder, `../kitty-cam` (see its README.md). It bundles
its own copy of the cat: `build.py` publishes `rig.json` and `engine.js` into `../kitty-cam/web/cat/`.

## Adding things

- **An expression:** add it to `poses.json`, run `build.py`. To trigger it, map an event to it in `Pet.qml`.
- **Motion or springs:** edit `engine.js`, run `build.py` (it copies the engine to both renderers).
- **A variant** (e.g. a tongue): add a `<g data-variant>` to the part in `rig.svg`, reference it from an expression.
- **A shape key:** for an ear-like flap, add a hinge key (`data-tip`). Otherwise copy the part's paths
  into a `<g data-key>` and move points without adding or removing any (`build.py` refuses a
  mismatch). Tune weights with the sliders in `preview.html`.
