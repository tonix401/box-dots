local function exec(cmd) return hl.dsp.exec_cmd(cmd) end

-- ── Window ────────────────────────────────────────────────────────────────────

-- Mouse drag / resize
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true, desc = "Drag window" })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(),   { mouse = true, desc = "Drag window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Resize window" })
hl.bind("SUPER + SHIFT + COMMA", hl.dsp.window.resize(), { mouse = false, desc = "Resize window left" })
hl.bind("SUPER + SHIFT + PERIOD", hl.dsp.window.resize(), { mouse = false, desc = "Resize window right" })

-- Focus direction
hl.bind("SUPER + Left",  hl.dsp.focus({ direction = "left"  }), { desc = "Focus window left" })
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "right" }), { desc = "Focus window right" })
hl.bind("SUPER + Up",    hl.dsp.focus({ direction = "up"    }), { desc = "Focus window up" })
hl.bind("SUPER + Down",  hl.dsp.focus({ direction = "down"  }), { desc = "Focus window down" })

-- Close / kill
hl.bind("SUPER + Q",       hl.dsp.window.close(),  { desc = "Close window" })
hl.bind("SUPER + ALT + Q", exec("hyprctl kill"),   { desc = "Kill window (pick with cursor)" })

-- Float / fullscreen / pin
hl.bind("SUPER + ALT + T", hl.dsp.window.float({ action = "toggle" }),              { desc = "Toggle floating" })
hl.bind("SUPER + F",       hl.dsp.window.fullscreen({ internal = 3, client = 3 }),  { desc = "Toggle fullscreen" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ internal = 0, client = 3 }),  { desc = "Toggle fullscreen (fake)" })
hl.bind("SUPER + P",       hl.dsp.window.pin(),                                     { desc = "Pin window" })
hl.bind("SUPER + T",       hl.dsp.window.tag({ tag = "full_opacity" }),             { desc = "Toggle transparency" })
-- ── Workspace ─────────────────────────────────────────────────────────────────

-- Navigate left / right
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "+1" }), { mouse = true, desc = "Next workspace" })
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "-1" }), { mouse = true, desc = "Previous workspace" })

-- Navigate to specific workspace
for i = 1, 9 do
    hl.bind("SUPER + " .. i,              hl.dsp.focus({ workspace = i }),                        { desc = "Go to workspace " .. i })
    hl.bind("SUPER + ALT + " .. i,        hl.dsp.window.move({ workspace = i, follow = true }),   { desc = "Move window to workspace " .. i })
    hl.bind("CTRL + SUPER + ALT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }),  { desc = "Send window to workspace " .. i })
end

-- Scratchpad / special
hl.bind("SUPER + S",         hl.dsp.workspace.toggle_special("scratchpad"),                           { desc = "Toggle scratchpad" })
hl.bind("SUPER + mouse:275", hl.dsp.workspace.toggle_special("scratchpad"),                           { mouse = true, desc = "Toggle scratchpad" })
hl.bind("SUPER + ALT + S",  hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), { desc = "Send window to scratchpad" })

-- ── Media ─────────────────────────────────────────────────────────────────────
local nextTrack = [[playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`]]
hl.bind("XF86AudioNext",  exec(nextTrack),              { locked = true, desc = "Next track" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86AudioPrev",  exec("playerctl previous"),   { locked = true, desc = "Previous track" })
hl.bind("XF86AudioPlay",  exec("playerctl play-pause"), { locked = true, desc = "Play / pause" })
hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true, desc = "Play / pause" })

-- ── Apps ──────────────────────────────────────────────────────────────────────
hl.bind("SUPER + Return",  exec("kitty"),                { desc = "Open terminal" })
hl.bind("SUPER + E",       exec("nemo"),                 { desc = "Open file manager" })
hl.bind("SUPER + W",       exec("chromium"),             { desc = "Open browser" })
hl.bind("SUPER + ALT + W", exec("chromium --incognito"), { desc = "Open browser (incognito)" })

-- ── Rofi Menus ────────────────────────────────────────────────────────────────
hl.bind("SUPER + K",      exec("~/.config/hypr/scripts/rofi/keybinds-menu.py"),          { desc = "Keybind reference" })
hl.bind("SUPER + SPACE",  exec("~/.config/hypr/scripts/rofi/app-launcher-menu.py"),      { desc = "App launcher" })
hl.bind("SUPER + ESCAPE", exec("~/.config/hypr/scripts/rofi/power-menu.py"),             { desc = "Power menu" })
hl.bind("SUPER + V",      exec("~/.config/hypr/scripts/rofi/clipboard-history-menu.py"), { desc = "Clipboard history" })
hl.bind("SUPER + PERIOD", exec("~/.config/hypr/scripts/rofi/emoji-picker-menu.py"),      { desc = "Emoji picker" })
hl.bind("SUPER + COMMA",      exec("~/.config/hypr/scripts/rofi/nerdfont-menu.py"),           { desc = "Nerd font picker" })
hl.bind("SUPER + P",      exec("~/.config/hypr/scripts/rofi/wallpaper-menu.py"),         { desc = "Wallpaper picker" })
hl.bind("SUPER + L",      exec("hyprlock"),                                              { desc = "Lock screen" })

-- ── Input Method ──────────────────────────────────────────────────────────────
hl.bind("CTRL + SPACE", exec("~/.config/waybar/scripts/fcitx-cycle.sh"), { desc = "Cycle input method" })

-- ─── Utils ────────────────────────────────────────────────────────────────────
hl.bind("SHIFT + SUPER + S", exec("~/.config/hypr/scripts/screenshot.py"), { desc = "Screenshot" })
hl.bind("SHIFT + SUPER + C", exec("hyprpicker | wl-copy"),                  { desc = "Pick color to clipboard" })

hl.bind("SUPER + TAB", function() hl.plugin.hyprexpo.expo("toggle") end, { desc = "Toggle workspace overview" })

hl.define_submap("hyprexpo",function()
    hl.bind("left",         function() hl.plugin.hyprexpo.kb_focus("left") end)
    hl.bind("right",        function() hl.plugin.hyprexpo.kb_focus("right") end)
    hl.bind("up",           function() hl.plugin.hyprexpo.kb_focus("up") end)
    hl.bind("down",         function() hl.plugin.hyprexpo.kb_focus("down") end)
    hl.bind("return",       function() hl.plugin.hyprexpo.kb_confirm() end)
    hl.bind("escape",       function() hl.plugin.hyprexpo.expo("cancel") end)
end)