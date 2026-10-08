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
| `kitty-cam.html` | Kitty Cam: the cat as a webcam, driven by your face and voice (see "Kitty Cam"). Carries its own copies of `rig.json` and `engine.js` like preview.html |
| `kitty-cam.py` | Serves kitty-cam.html, opens it in its own Chromium, and writes the frames it draws to the "Kitty Cam" v4l2loopback camera |
| `voice.py` | The sing-along analyser Pet.qml runs: listens to the speakers while something plays, prints mouth shapes (see "Singing") |
| `build.py --export cat\|fat-cat` | The two original drawings on demand, path data verbatim (`--color '#hex'`, else matugen's color tag). They used to be matugen templates rendered for the kitty greeting; since 2026-10-07 nothing renders them |

Renderers: `~/.config/quickshell/components/Cat.qml` (used by `KittyCat.qml`, a cat in the top right
corner of every kitty window, driven by `Pet.qml`), `preview.html` (SVG) and `kitty-cam.html` (Canvas 2D).
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
7. **Face tracking** (`track(st, pose | null)`, used by kitty-cam.html; `st.restMouth`: see Kitty Cam → Cat settings): `tracked` eases 0 ↔ 1 (~0.25 s)
   as a face is found or lost, and scales everything here. The face replaces the idle blinks, twitches
   and tilts; breathing, motions and springs stay. Head: `rot += roll`, leans by `x`/`y`, narrows a
   little with |yaw|. A turn is faked by parallax: the head's children slide by `8·depth·yaw`,
   `5·depth·pitch` (eyes 1, mouth/sing/cheeks 1.15, sweat 0.8, whiskers 0.6, bow 0.4, ears −0.3), and the
   far eye narrows. Each eye closes with its own lid (`sy × (1 − 0.9 blink)`, blinkable variants only) and
   shifts with the gaze (±1.5). The ears are the eyebrows (`brow` > 0 → `perk`, < 0 → `flat`). The sing
   mouth shows and follows the pose's `open`/`wide`/`round`; the cheeks blush at least by `smile`.
8. **Singing** (`voice(st, [active, open, wide, round])`): in an expression with `sing`, while `active`,
   the `sing` mouth fades in over `mouth` (~0.12 s) and its keys follow `open`/`wide`/`round` (~0.05 s);
   the head lifts by up to 0.8 as the mouth opens.

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

## Kitty Cam (kitty-cam.py, kitty-cam.html)

The cat as a webcam for video calls: pick **Kitty Cam** as the camera in Meet, Zoom, Discord, …

```
webcam (via PipeWire), mic → kitty-cam.html: MediaPipe Face Landmarker → One Euro filters → CatEngine.track → canvas
            → worker: RGBA → YUV 4:2:0 → POST /frame (30 fps) → kitty-cam.py → write() → /dev/video10 "Kitty Cam"
```

- **Run** `./kitty-cam.py` (`--headless`: no window; `--no-browser`: only serve http://127.0.0.1:8737/;
  `--no-camera --port 8738`: a second instance for testing that leaves the camera alone).
  `curl 127.0.0.1:8737/status` shows the page's own figures (tracking fps, detection ms, camera size, face, calibration).
  It opens the page in its own Chromium profile (`~/.cache/kitty-cam/chromium`) with background
  throttling off and autoplay allowed (the camera/mic prompt comes once; the profile remembers it;
  `--headless` grants them by flag). The loop runs on a timer, not
  `requestAnimationFrame`, so the cat keeps moving while the call's window covers this one. Closing
  the window stops it. MediaPipe (`@mediapipe/tasks-vision`, pinned in kitty-cam.py) and the
  `face_landmarker.task` model are downloaded once to `~/.cache/kitty-cam/vendor/`.
- **Setup, once:** `sudo pacman -S --needed v4l2loopback-dkms`;
  `/etc/modprobe.d/v4l2loopback.conf`: `options v4l2loopback devices=3 video_nr=9,10,11 card_label="OBS Virtual Camera,Kitty Cam,Shared Webcam" exclusive_caps=1,1,1`
  (`exclusive_caps=1`: Chrome/WebRTC only list a loopback that looks like a capture device; the labels go in
  one quoted list, as `"a","b"` keeps the quotes in the names; OBS's virtual camera takes the first loopback
  that accepts output, so its device has to come before Kitty Cam's);
  `/etc/modules-load.d/v4l2loopback.conf`: `v4l2loopback`. Without the device the page still runs.
- **The webcam is shared:** the page reads it through PipeWire (`--enable-features=WebRtcPipeWireCamera`,
  merged with `~/.config/chromium-flags.conf`'s, as Chromium keeps only the last such flag), so it never holds
  `/dev/video0` itself. OBS reads the webcam with its PipeWire source; V4L2-only apps (Discord) pick
  "Shared Webcam", which `~/.local/bin/shared-webcam` (user service `shared-webcam`) fills from PipeWire
  while something streams it. WirePlumber leaves the loopback devices alone
  (`~/.config/wireplumber/wireplumber.conf.d/50-v4l2loopback.conf`).
- **Frames** leave the page already in the camera's format, YUV 4:2:0 (`YU12`, BT.601 limited range),
  converted in a Worker (so face detection never delays them) and POSTed raw (1.38 MB each). kitty-cam.py
  sets the device's format once (`VIDIOC_S_FMT`; while a reader such as OBS streams, it checks with
  `VIDIOC_G_FMT` that the format is already ours) and `write()`s each frame as it is. This replaced
  JPEG + ffmpeg on 2026-10-08: ffmpeg's image2pipe held every frame ~104 ms (measured in isolation;
  `-threads 1` / `low_delay` didn't help).
- **Delay, measured 2026-10-08:** drawn → helper ~17 ms; drawn → OBS preview ~64 ms (32–77), with OBS's
  V4L2 source at its default "Use buffering" on (turning it off should take more off; not measured). 30 fps,
  also with the window hidden. **Measuring it:** `?stamp=1` draws the page's clock as a barcode at the top
  left (red end marks, 32 black/white 24 px cells); decode it from the device, or from one screenshot that
  shows both the page and OBS's preview. kitty-cam.py's `/status` has `drawn_to_helper_ms`. This
  v4l2loopback (0.15) lets only one reader stream at a time, so the device can't be read while OBS has it.
- **Fill** (Look → fill, colour picker and palette swatches beside it; default matugen's `primary_container`): fills the
  cat's silhouette behind its lines, so a busy background never shows through it (e.g. once OBS keys the
  background colour out). The silhouette is rebuilt every frame from the live outline pieces (head
  cheeks and crown, both ears' outer paths, the body's sides, legs and bottom, slim or fat), taken from
  the engine's frame (shape keys, skinning and matrices applied), so it follows every tilt, squash and
  ear flick.
- **Camera input** is 1280×720 (MediaPipe works on a crop around the face, so more pixels there help). The
  loop polls for new camera frames at 60 Hz and draws/sends at 30: polling at 30 Hz could miss frames.
  This webcam delivered ~21 fps in room light (2026-10-08) and has no exposure controls; more light on
  the face is the way to more frames.
- **Devices:** the page's Input card picks the camera and the microphone; the choice is remembered
  (localStorage `kitty-cam.camera` / `kitty-cam.microphone`; Chromium keeps device ids stable per site), and a
  remembered device that's gone falls back to the default. The lists follow devices being plugged in. Switching
  cameras suggests recalibrating, as the head's neutral position moves with the camera.
- **The page never tracks Kitty Cam itself**: it's left out of the camera list, and if the default camera is
  Kitty Cam, the first other camera is used.
- **Measures**, all unmirrored and on the subject's left/right (MediaPipe's `…Left` blendshapes are the
  subject's left: verified 2026-10-08 by painting one eye of a test portrait shut). Besides the 52
  blendshapes and the head matrix, the page measures the landmarks directly, scaled by the distance
  between the outer eye corners (33, 263), so they hold at any distance: `gap` between the inner lips
  (13, 14), mouth `width` (61, 291), each eye's aspect ratio (`earR` 33/160/158/133/153/144, `earL`
  362/385/387/263/373/380), and `irisX`, the irises (468, 473) between their eye corners.
- **Mapping** (mirrored by default, so the cat moves like your reflection):
  - head: yaw/pitch over your own comfortable turn (calibrated; default 25° sideways, 15° up, 18°
    down) is a full turn, roll in degrees, lean from the translation (cm × 0.7 → rig units)
  - lids: ½ blink blendshape + ½ eye ratio, each minus what a smile's squint adds (`leak`), then
    **blink sync**: lids within ~0.25 of each other close together, so blinks never come out as half winks
  - gaze: sideways from the irises (held while the lids are closed), up/down from the `eyeLook*` blendshapes
  - mouth: `open` from the lip gap; `wide` / `round` from the stretch and smile / funnel and pucker
    blendshapes, and, once calibrated, from the width against your resting mouth ("ee" wider, "oo"
    narrower; an "ah" also narrows it, so that counts less while open)
  - ears: brows up (`browInnerUp`, `browOuterUp*`) minus the frown (`browDown*` minus the smile's leak)
  - every value is `(v − rest) / (far end − rest)`, then a One Euro filter run per camera frame (head
    and lean with a high beta, so fast moves aren't smoothed into lag)
- **Calibrate** (since 2026-10-08): one button per movement, recorded whenever you're ready and redone
  any time: neutral face (also `C`), mouth wide open, big smile, "eee", "ooo", brows up, frown, eyes
  closed, head left / right / up / down. A click gives a 1.2 s count-in, then records ~1.5 s, then beeps
  (your cue to relax, or to open your eyes). Each recording (the frames' measures and the blendshapes the
  mapping uses, rounded) is kept in localStorage (`kitty-cam.calibration-steps`), and the calibration is
  worked out again from all of them: the neutral face gives the resting values and the head's zero (it's
  needed before anything else counts); each other movement gives the far end of its range (a percentile,
  and only if the movement clearly happened, otherwise the default stays), the head turns give your
  range, and the smile also gives its leak into lids and brows. (This replaced a ~30 s automatic run
  whose prompts changed too fast.)
  Uncalibrated, leaning is measured from where the head has been over the last ~4 s.
- **Mic**: loudness over an adaptive noise floor (`talk`); `open = max(open, 0.7 talk)`. With no face
  in view the cat still talks from the mic alone (through `voice`). Switch "Mic lip sync" off (Cat settings
  → Mouth) if the mic hears the call's audio (no headphones).
- **Cat settings** (since 2026-10-08; localStorage `kitty-cam.settings`, "defaults" resets): three groups
  of plain choices (a row of buttons per choice) and on/off switches. No strength sliders: how strongly the
  cat follows you comes from the calibration (the user asked for choices, not sliders).
  - Look: eyes (sparkly, round, wide, ✦, > <, ‿ ‿, × ×, shades = the `shades` part over closed eyes; only round, wide and sparkly can blink), mouth
    when closed (talking = the `sing` mouth always; ω / smile / o / none: the engine's `st.restMouth`
    shows that mouth while the tracked lips are closed and the sing mouth while they move, with a little
    hysteresis), body (slim / chubby = `fat`), blush (when smiling / always / never), bow tie, whiskers
  - Tracking: head, blinks, gaze, mouth, ears follow brows, mic lip sync. A switched-off part gets zeros
    from the face; for the head and the blinks the engine's own idle tilts and blinks carry on instead
    (`st.trackHead`, `st.trackBlink`)
  - Behaviour: mirror (was a button in the Input card), blink together (blink sync), idle animation (the
    engine's `st.idle`: breathing, and the blinks, twitches and tilts while no face is tracked)

  The look always wins: the page writes it into every expression of its own copy of rig.json's
  expressions (which the engine reads live), so a mood keeps only its extras (motions, ear keys, the
  zzz, the sweat drop, sleepy's half-closed eyes).
- **Moods** (the rig's expressions, keys `1`–`9`, `0` neutral) are **presets**: clicking one sets the look
  to the mood's own (eyes, mouth, body, blush; neutral's mouth is "talking"), shown in the settings to
  change from there, and plays the mood for its extras. The mood is remembered. **Actions:** hop (`Space`)
  and squish (hold the button or `S`; the squash spring boings back on release).
- **Foldable cards:** Input, Calibration and Colours (the set-up-once ones) are `<details>`; which are open
  is remembered (`kitty-cam.open`). Calibration starts open until a neutral face is recorded.
- **Keys** (window focused): `1`–`9` moods, `0` neutral, `Space` hop, hold `S` squish, `C` record the
  neutral face.
- **Colours** (foldable card): lines, fill and background each have a free colour picker. Lines and fill also get
  swatches of matugen's palette (`/theme` → `palette`: primary, secondary, tertiary, their containers
  and on-containers, inverse primary, surface container highest, on surface, outline, error, from
  quickshell's colors.json). The defaults are `primary` lines, `surface` background, `primary_container` fill;
  "theme" goes back to them.
- Devtools: `kittyCam.raw` is the last face as MediaPipe saw it, `kittyCam.st.pose` what the cat got.

## Adding things

- **An expression:** add it to `poses.json`, run `build.py`. To trigger it, map an event to it in `Pet.qml`.
- **Motion or springs:** edit `engine.js`, run `build.py` (it copies the engine to both renderers).
- **A variant** (e.g. a tongue): add a `<g data-variant>` to the part in `rig.svg`, reference it from an expression.
- **A shape key:** for an ear-like flap, add a hinge key (`data-tip`). Otherwise copy the part's paths
  into a `<g data-key>` and move points without adding or removing any (`build.py` refuses a
  mismatch). Tune weights with the sliders in `preview.html`.
