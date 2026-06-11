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
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})