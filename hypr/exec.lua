-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- The session runs under uwsm, so some things are not started here:
--   env export          uwsm pushes the login env to systemd + D-Bus before Hyprland starts
--   portals             D-Bus-activated units (xdg-desktop-portal{,-hyprland,-gtk}.service)
--   cliphist            cliphist.service
--   hyprpolkitagent     hyprpolkitagent.service, wanted by graphical-session.target
--   fcitx5              XDG autostart (app-org.fcitx.Fcitx5@autostart.service)
-- Long-running apps go through `uwsm app --` so each gets its own systemd scope
-- (own cgroup, journal tag) instead of living inside Hyprland's unit. It keeps the PID,
-- so the workspace option below still applies.

local function app(cmd, opts) hl.exec_cmd("uwsm app -- " .. cmd, opts) end

hl.on("hyprland.start", function()
  app("awww-daemon")
  app("qs") -- bar + menus, ~/.config/quickshell
  app("xsettingsd")
  app("obsidian", { workspace = "5 silent" }) -- vault ~/knowledge; its CLI needs the app running
  app("anki", { workspace = "5 silent" }) -- for flashcards, its CLI needs the app running
  hl.exec_cmd("hyprpm reload")
end)
