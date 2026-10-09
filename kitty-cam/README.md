# Kitty Cam

The cat avatar as a webcam for video calls: pick **Kitty Cam** as the camera in Meet, Zoom, Discord, … and the
cat follows your face (MediaPipe) and your voice. Everything it needs is in this folder, so the folder can live
anywhere and be copied as it is. The camera is a PipeWire camera, so any number of apps can show it at once.

## Use

```
./kitty-cam                     open the window and feed the camera; closing the window stops it
./kitty-cam --headless          the same without a window (controls at http://127.0.0.1:8737/)
./kitty-cam --no-browser        only serve; open http://127.0.0.1:8737/ in a Chromium-based browser
./kitty-cam --stop              stop the running instance
./kitty-cam --theme FILE        take the colours from a Material-You palette JSON (matugen's shape:
                                {"primary": "#…", "surface": "#…", "primary_container": "#…", …}); also $KITTY_CAM_THEME
./kitty-cam --no-camera --port 8738 --no-browser
                                a second instance for testing that leaves the camera alone
./install.sh [--theme FILE]     add a launcher (desktop entry + icon) for this folder; again after moving it
./install.sh --uninstall        remove the launcher
```

Needs Python 3.9+, Chromium (or Chrome) and, for the camera, PipeWire and GStreamer with `pipewiresink`
(see Setup below). The settings,
calibration and colours chosen in the window are kept in its Chromium profile, per port: keep the default
port to keep them.

On the box this lives on, the launcher is installed with
`./install.sh --theme ~/.config/quickshell/colors.json`, so the cat matches the desktop's matugen colours.

## Files

| | |
|---|---|
| `kitty-cam` | The entry point (`--help`) |
| `kittycam/cli.py` | Command line, start/stop (pid file in `$XDG_RUNTIME_DIR`), the main loop |
| `kittycam/server.py` | The local HTTP server: the page, `/vendor/`, `/theme`, `/status`, `POST /frame` |
| `kittycam/camera.py` | The PipeWire camera: a gst-launch pipeline fed the frames on its stdin |
| `kittycam/browser.py` | The page's own Chromium window or headless Chromium |
| `kittycam/assets.py` | MediaPipe, downloaded once into the cache (pinned version) |
| `kittycam/theme.py` | `--theme`: a palette file → the page's colours and swatches |
| `kittycam/paths.py` | Where things are: this folder, and the XDG cache/config/runtime dirs |
| `web/index.html`, `style.css`, `icon.svg` | The page's markup, styles and icon |
| `web/js/main.js` | Wires the page up and runs the loop: track → draw → send |
| `web/js/cat.js`, `render.js` | The cat's rig and engine state; drawing it on the canvas |
| `web/js/settings.js`, `moods.js`, `colours.js` | The Cat settings, Moods and Colours cards |
| `web/js/input.js`, `mic.js`, `tracker.js` | Camera and mic choice, the mic's loudness, MediaPipe |
| `web/js/face.js`, `pose.js`, `ranges.js`, `one-euro.js` | A MediaPipe result → raw measures → the cat's pose (calibrated, filtered) |
| `web/js/calibration.js` | The Calibration card and working the calibration out |
| `web/js/overlay.js` | What tracking measured, drawn over the camera preview |
| `web/js/sender.js`, `encoder-worker.js` | Frames to the server, converted to YUV 4:2:0 in a worker |
| `web/cat/rig.json`, `engine.js` | The cat itself. **Generated:** published here by the cat's build (`../cat/build.py`, see `../cat/SPEC.md`); edit the rig there |

## How it works

```
webcam (via PipeWire), mic → the page (web/): MediaPipe Face Landmarker → One Euro filters → CatEngine.track → canvas
            → worker: RGBA → YUV 4:2:0 → POST /frame (30 fps) → kitty-cam → gst-launch → PipeWire camera "Kitty Cam"
```

- **The server** (`kittycam/server.py`) only listens on 127.0.0.1. Only its own page may use the server: requests under any other host name are refused (DNS rebinding), and frames
  are taken only with the page's own `Origin` (any other site could POST to 127.0.0.1 and put its pictures in the camera).
  `curl 127.0.0.1:8737/status` shows the page's own figures (tracking fps, detection ms, camera size, face, calibration).
  It opens the page in its own Chromium profile (`$XDG_CACHE_HOME/kitty-cam/chromium`) with background
  throttling off and autoplay allowed (the camera/mic prompt comes once; the profile remembers it;
  `--headless` grants them by flag). The loop runs on a timer, not
  `requestAnimationFrame`, so the cat keeps moving while the call's window covers this one. Closing
  the window stops it. MediaPipe (`@mediapipe/tasks-vision`, pinned in `kittycam/assets.py`) and the
  `face_landmarker.task` model are downloaded once to `$XDG_CACHE_HOME/kitty-cam/vendor/`.
- **Setup, once:** `sudo pacman -S --needed gstreamer gst-plugins-base gst-plugin-pipewire` (PipeWire itself
  runs already on a normal desktop). Without them the page still runs, and kitty-cam says what's missing.
- **The camera is shared:** kitty-cam publishes it to PipeWire (`pipewiresink mode=provide`, node
  `kitty_cam`, started on the first frame), and PipeWire serves it to any number of apps at once. Apps see it
  if they take cameras from PipeWire: Chromium with `--enable-features=WebRtcPipeWireCamera` (on in
  `~/.config/chromium-flags.conf`, so Discord in the browser too), OBS's "Video Capture Device (PipeWire)".
  Apps that only open `/dev/video*` (the native Discord app) don't see it. Until 2026-10-09 it was the
  v4l2loopback device `/dev/video10`, which serves only one reader at a time.
- **The webcam is shared** the same way: the page reads it through PipeWire (`WebRtcPipeWireCamera`,
  merged with `~/.config/chromium-flags.conf`'s, as Chromium keeps only the last such flag), so it never holds
  `/dev/video0` itself; nothing else may either, or PipeWire can't open it (`Device or resource busy`).
  OBS's virtual camera reaches PipeWire through `~/.local/bin/obs-camera` (user service `obs-camera`).
- **Frames** leave the page already in YUV 4:2:0 (`I420`, BT.601 limited range), converted in a Worker (so
  face detection never delays them) and POSTed raw (1.38 MB each). kitty-cam writes each to gst-launch's
  stdin (`fdsrc ! rawvideoparse`), which converts it to YUY2 and hands it to PipeWire: Chromium's PipeWire
  camera shows no frames for I420 or NV12 (Chromium 153, tested 2026-10-09). A leaky queue drops frames
  instead of ever holding up the server. (JPEG + ffmpeg, before 2026-10-08, held every frame ~104 ms.)
- **Delay:** measured 2026-10-08 on the old v4l2loopback path: drawn → helper ~17 ms; drawn → OBS preview
  ~64 ms (32–77). The PipeWire path isn't measured yet. 30 fps, also with the window hidden.
  **Measuring it:** `?stamp=1` draws the page's clock as a barcode at the top left (red end marks, 32
  black/white 24 px cells); decode it from one screenshot that shows both the page and OBS's preview.
  kitty-cam's `/status` has `drawn_to_helper_ms`.
- **Fill** (Colours → fill, colour picker and palette swatches beside it; default matugen's `primary_container`): fills the
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
- **The head turns in 3D:** the cat's head is a real 3D solid inflated from its drawing (`../cat/SPEC.md`, "The 3D
  head"), so your yaw and pitch turn it: its outline is the solid's silhouette, the face and whiskers turn with it
  and go behind it, the bow tie only moves. Try it without a camera in the rig's preview (`../cat/preview.html`,
  "Head turn" sliders).
- **Seeing what tracking measured:** Input → camera preview shows the camera with the tracking drawn over it
  (`web/js/overlay.js`), mirrored like the preview. On the face: the landmarks, each eye's six points with its
  aspect ratio (`eye`, how open it is), the irises and where they sit between the eye corners (`iris`), the gap
  between the lips and the mouth's width (both divided by the dashed eye-corner distance, the face's size), and
  an arrow from the nose the way the head points, with its raw angles. In the corner away from the face: the
  pose the cat gets from all that, after calibration and smoothing (`pose · calibrated` or `· defaults`), as
  bars; signed ones are marked in the middle.
- Devtools: `kittyCam.raw` is the last face as MediaPipe saw it, `kittyCam.pose` what the cat got from it.
