-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Theming settings (not sure if this makes sense tbh)
hl.env("XCURSOR_THEME",         "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE",          "24")
hl.env("HYPRCURSOR_SIZE",       "24")
hl.env("QT_QPA_PLATFORMTHEME",  "gtk2")
hl.env("QT_QPA_PLATFORMTHEME_QT6", "gtk4")
hl.env("GTK_THEME",             "Adwaita:dark")

-- Input method settings for fcitx5
hl.env("QT_IM_MODULE",  "fcitx")
hl.env("XMODIFIERS",    "@im=fcitx")