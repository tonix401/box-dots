require("exec")
require("keybinds")
require("env")
require("look")
require("windowrules")

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-----------------
----  INPUT  ----
-----------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "intl",
    },
    general = {
        layout = "dwindle",
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    dwindle = {
        -- When moving windows, the new position is calculated
        -- based on the mouse position on the underlying window.
        -- This does not apply to new windows, unlike smart_split.
        -- (I dont want it for new windows, the standard behaviour is way better for that)
        precise_mouse_move = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
    plugin = {
        hyprexpo = {
            columns = 3,
            gaps_in = 8,
            gaps_out = 8,
            bg_col = "rgb(000000)",
            workspace_method = "center current",
            show_cursor = 1,
            tile_rounding = 12,
            tile_rounding_power = 2.0
        },
    },
})

