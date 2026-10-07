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
| `rig.json` | Generated manifest for renderers |
| `preview.html` | Browser renderer + tuning panel (expressions, motions, shape-key sliders; hold the mouse on the cat to squish it). Carries its own copies of `rig.json` and `engine.js`; `?expr=startled&idle=0` |
| `~/.config/quickshell/components/CatEngine.js` | Generated copy of `engine.js` for Cat.qml |
| `build.py --export cat\|fat-cat` | The two original drawings on demand, path data verbatim (`--color '#hex'`, else matugen's color tag). They used to be matugen templates rendered for the kitty greeting; since 2026-10-07 nothing renders them |

Renderers: `~/.config/quickshell/components/Cat.qml` (used by `KittyCat.qml`, a cat in the top right
corner of every kitty window, driven by `Pet.qml`) and `preview.html`.
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
- `class`: `line` = miter joins, `line-join` / `ear` = round joins, `filled` = filled with the stroke
  color, `solid` = filled, no stroke, `blush` = fill at 35 % opacity, `hole` = cut out of the filled
  shape just before it (even-odd; the eye highlights).

### Parts (paint order)

| Part | Parent | Pivot | Variants / keys |
|---|---|---|---|
| `body` | – | feet centre | `slim` (cat.svg), `fat` (fat-cat.svg); skinned to `head` over y 98–132 |
| `head` | – | chin | outline (cheeks + crown) |
| `bow` | head | bow centre | |
| `ear-l`, `ear-r` | head | ear base midpoint | hinge keys `twitch` (tip 14° out), `flat` (tip 50° out and down to 74 %), `perk` (tip 10° up, 108 %) |
| `whiskers-l`, `whiskers-r` | head | where they meet the cheek | |
| `eyes` | head | between the eyes | `open`, `sparkle` (bigger, with highlights), `squint` (`> <`), `closed` (`‿ ‿`), `x` (`× ×`), `stars` (`✦ ✦`), `wide` (rings + pupils, unused) |
| `cheeks` | head | | hidden by default; blush |
| `sweat` | head | | hidden by default; a drop at the right temple |
| `mouth` | head | mouth | `smile` (cat.svg), `cat` (`ω`), `none`, `open` |
| `zzz` | – | | hidden by default; three z's |

## rig.json

```
{ version, viewBox, origin,            // the exports' viewBox and translate
  canvas: [x, y, w, h],                // part coordinates covering every variant and key, plus margin
  stroke: {width: 2, cap: "round"},
  order: [part, ...],                  // paint order; parents come before their children
  parts: { name: { parent, pivot: [x, y], hidden,
                   variants: { name: [ {paths: [{pts, closed}], stroke, fill, alpha, join, evenodd, d} ] },
                   keys: { name: [ [pts per subpath] per shape ] },         // matches the "default" variant
                   skin: null | {bone, weights: {variant: [ [ [w per point] per subpath ] per shape ]}} } },
  expressions: { name: { variants: {part: variant}, keys: {"part.key": w},
                         transforms: {part: {tx, ty, sx, sy, rot}}, show: [part], motion, breath } } }
```

`pts` is `[P0, C1, C2, P1, C1, C2, P2, …]`: every path is absolute cubic Béziers only (lines are
converted), so blending is a plain point-wise lerp. A shape's first subpath is its outline, the
rest are holes. `d` is the whole shape as an SVG string.

**Transforms.** A part's local matrix is
`translate(pivot + (tx, ty)) · rotate(rot°) · scale(sx, sy) · translate(−pivot)`, and its world
matrix is `parent world · local`. `rot` is in degrees, clockwise on screen (y points down).

## Expressions (poses.json)

| | Eyes | Mouth | Body | Keys / transforms / shown | Motion |
|---|---|---|---|---|---|
| `neutral` | sparkle | cat | slim | | |
| `happy` | squint | cat | slim | cheeks | `hop` on entry |
| `purr` | squint | cat | slim | ears `flat` 0.3, cheeks | |
| `vibing` | squint | cat | slim | cheeks | `bob` while held |
| `sleepy` | open | none | slim | ears `flat` 0.3, eyes `sy` 0.35 | |
| `asleep` | closed | cat | fat | ears `flat` 0.5, zzz, cheeks | breath every 6 s |
| `impressed` | stars | open | slim | ears `perk` 1, cheeks | `jolt` on entry |
| `straining` | squint | none | slim | sweat drop | `tremble` while held (whole cat ±0.5 at 13 Hz) |
| `startled` | x | open | slim | | `jolt` on entry |

`exports.cat` / `exports["fat-cat"]` are the poses of the two original drawings (`build.py --export`).

## Animation (engine.js, each frame)

1. **Ease** every part's transform, key weights and visibility towards the expression's (settling in
   ~0.22 s); variant opacities crossfade (~0.12 s). `v = goal + (v − goal)·e^(−4.6·dt/settle)`.
2. **Idle loop** on top:
   - blink: eyes `sy` × (1 → 0.1 → 1) over 0.16 s (0.5 s sleepy), every 3–7 s, 15 % double; `open`/`sparkle`/`wide` eyes only
   - ear twitch: one ear's `twitch` += |sin 2πp| over 0.36 s, every 8–20 s, its whiskers turning ±3°
   - head tilt: every 9–22 s the head tilts 7° one way for 1.8 s (through the tilt spring, so it overshoots)
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

**Busy:** while a command runs in a kitty window (anything but interactive programs: nvim, ssh, less,
man, htop/btop, claude, tmux, … in any part of a pipeline, and shells/REPLs started bare), that
window's cat is squished flat and `straining` until the command finishes, then boings back — with the
command's reaction, if any. A squish lasts exactly as long as the command (no minimum). The fish
hook sends `busyPid <pid> <id>` before and `finishedPid <pid> <id> <event|none>` after each command; the
per-command id makes the two racing calls safe (a `busy` after its `finished` is ignored).

One cat shows: its window's reaction, else an every-cat reaction, else `straining` while busy, else
the pin, else the base mood.
A reaction for every cat replaces any per-window ones. The fish hook sends kitty's `$KITTY_PID`;
each kitty window is its own process, so Quickshell finds the window by its Hyprland `pid` (if
several share one, the focused one).

`qs ipc call cat react <event>` (every cat), `qs ipc call cat reactPid <event> <pid>` (the window of
that process), `busyPid <pid> <id>` / `finishedPid <pid> <id> <event|none>` (the squish around a command), `qs ipc call cat mood <expression>` (pins it in place of the base mood; reactions still
play over it), `qs ipc call cat unpin`, `qs ipc call cat tester` or **SUPER + SHIFT + C** (the CatTester panel; its "only …"
toggle aims reactions at the focused window), `qs ipc call cat kitty` (hide/show the cats).

## Adding things

- **An expression:** add it to `poses.json`, run `build.py`. To trigger it, map an event to it in `Pet.qml`.
- **Motion or springs:** edit `engine.js`, run `build.py` (it copies the engine to both renderers).
- **A variant** (e.g. a tongue): add a `<g data-variant>` to the part in `rig.svg`, reference it from an expression.
- **A shape key:** for an ear-like flap, add a hinge key (`data-tip`). Otherwise copy the part's paths
  into a `<g data-key>` and move points without adding or removing any (`build.py` refuses a
  mismatch). Tune weights with the sliders in `preview.html`.
