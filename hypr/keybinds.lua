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

-- Close / kill
hl.bind("SUPER + Q",              hl.dsp.window.close())
hl.bind("SUPER + ALT + Q", exec("hyprctl kill"))

-- Float / fullscreen / pin
hl.bind("SUPER + ALT + T",  hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F",        hl.dsp.window.fullscreen({ internal = 3, client = 3 })) -- not working well
hl.bind("SUPER + ALT + F",  hl.dsp.window.fullscreen({ internal = 0, client = 3 })) -- not working well
hl.bind("SUPER + P",        hl.dsp.window.pin())

-- ── Workspace ─────────────────────────────────────────────────────────────────

-- Navigate left / right
hl.bind("SUPER + mouse_up",           hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_down",         hl.dsp.focus({ workspace = "-1" }))

-- Navigate to specific workspace
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + ALT + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
    hl.bind("CTRL + SUPER + ALT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Scratchpad / special
hl.bind("SUPER + S",          hl.dsp.workspace.toggle_special())
hl.bind("SUPER + mouse:275",  hl.dsp.workspace.toggle_special())
hl.bind("SHIFT + SUPER + M",  hl.dsp.window.move({ workspace = "special", follow = false }))

-- ── Media ─────────────────────────────────────────────────────────────────────

local nextTrack = [[playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`]]
hl.bind("XF86AudioNext",     exec(nextTrack),              { locked = true })
hl.bind("XF86AudioPrev",     exec("playerctl previous"),   { locked = true })
hl.bind("XF86AudioPlay",     exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",    exec("playerctl play-pause"), { locked = true })

-- ── Apps ──────────────────────────────────────────────────────────────────────
hl.bind("SUPER + Return",    exec("kitty"))
hl.bind("SUPER + E",         exec("nemo"))
hl.bind("SUPER + W",         exec("chromium"))
hl.bind("SUPER + ALT + W",   exec("chromium --incognito"))

-- ── Rofi Menus ────────────────────────────────────────────────────────────────
hl.bind("SUPER + SPACE",     exec("~/.config/hypr/scripts/rofi/launcher"))
hl.bind("SUPER + ESCAPE",    exec("~/.config/hypr/scripts/rofi/powermenu"))
hl.bind("SUPER + V",         exec("~/.config/hypr/scripts/rofi/clipboard"))
hl.bind("SUPER + PERIOD",    exec("~/.config/hypr/scripts/rofi/emoji"))

-- ─── Utils ────────────────────────────────────────────────────────────────────
hl.bind("SHIFT + SUPER + S", exec("~/.config/hypr/scripts/screenshot"))