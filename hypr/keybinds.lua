local function exec(cmd) return hl.dsp.exec_cmd(cmd) end

-- ── Window ────────────────────────────────────────────────────────────────────

-- Mouse drag / resize
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus direction
hl.bind("SUPER + Left",        hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + Right",       hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + Up",          hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + Down",        hl.dsp.focus({ direction = "down" }))

-- Move window in tiling direction
hl.bind("SUPER + SHIFT + Left",  hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + Up",    hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + Down",  hl.dsp.window.move({ direction = "d" }))

-- Close / kill
hl.bind("SUPER + Q",              hl.dsp.window.close())
hl.bind("SUPER + ALT + Q", exec("hyprctl kill"))

-- Float / fullscreen / pin
hl.bind("SUPER + ALT + T",  hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + D",        hl.dsp.window.fullscreen(1))
hl.bind("SUPER + F",        hl.dsp.window.fullscreen(0))
hl.bind("SUPER + ALT + F",  hl.dsp.window.fullscreen(0, 3))
hl.bind("SUPER + P",        hl.dsp.window.pin())

-- ── Workspace ─────────────────────────────────────────────────────────────────
-- Navigate left / right
hl.bind("CTRL + SUPER + Right",       hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + SUPER + Left",        hl.dsp.focus({ workspace = "r-1" }))
hl.bind("CTRL + SUPER + ALT + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("CTRL + SUPER + ALT + Left",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind("SUPER + Page_Down",          hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + Page_Up",            hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL + SUPER + Page_Down",   hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + SUPER + Page_Up",     hl.dsp.focus({ workspace = "r-1" }))
hl.bind("SUPER + mouse_up",           hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_down",         hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL + SUPER + mouse_up",    hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + SUPER + mouse_down",  hl.dsp.focus({ workspace = "r-1" }))
-- Scratchpad / special
hl.bind("SUPER + S",          hl.dsp.workspace.toggle_special())
hl.bind("SUPER + mouse:275",  hl.dsp.workspace.toggle_special())
hl.bind("CTRL + SUPER + BracketLeft",  hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL + SUPER + BracketRight", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL + SUPER + Up",   hl.dsp.focus({ workspace = "r-5" }))
hl.bind("CTRL + SUPER + Down", hl.dsp.focus({ workspace = "r+5" }))

-- ── Media ─────────────────────────────────────────────────────────────────────

local nextTrack = [[playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`]]
hl.bind("SUPER + SHIFT + N",           exec(nextTrack),              { locked = true })
hl.bind("XF86AudioNext",               exec(nextTrack),              { locked = true })
hl.bind("XF86AudioPrev",               exec("playerctl previous"),   { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:275", exec("playerctl previous"))
hl.bind("SUPER + SHIFT + ALT + mouse:276", exec(nextTrack))
hl.bind("SUPER + SHIFT + B", exec("playerctl previous"),   { locked = true })
hl.bind("SUPER + SHIFT + P", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",     exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",    exec("playerctl play-pause"), { locked = true })

-- ── Apps ──────────────────────────────────────────────────────────────────────
hl.bind("SUPER + Return",       exec("kitty"))
hl.bind("SUPER + E",            exec("nemo"))
hl.bind("SUPER + W",            exec("chromium"))
hl.bind("SUPER + ALT + W",      exec("chromium --incognito"))
hl.bind("SUPER + SPACE",        exec("rofi -show drun -theme ~/.config/rofi/launcher.rasi"))
hl.bind("SUPER + ESCAPE",       exec("~/.config/hypr/scripts/powermenu"))
hl.bind("SUPER + V",            exec("~/.config/hypr/scripts/clipboard"))
hl.bind("SUPER + PERIOD",       exec("~/.config/hypr/scripts/emoji"))