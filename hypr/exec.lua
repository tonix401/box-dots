-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
  -- On NixOS this also starts graphical-session.target (via hyprland-session.target from home.nix),
  -- which session services like dcal wait for.
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland && { [ -e /etc/NIXOS ] && systemctl --user start hyprland-session.target; }")
  -- NixOS starts the portals itself and loads plugins in hyprland.lua instead of hyprpm
  hl.exec_cmd("[ -e /etc/NIXOS ] || /usr/lib/xdg-desktop-portal-hyprland")
  hl.exec_cmd("[ -e /etc/NIXOS ] || /usr/lib/xdg-desktop-portal-gtk")
  hl.exec_cmd("[ -e /etc/NIXOS ] || /usr/lib/xdg-desktop-portal --replace")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("qs") -- bar + menus, ~/.config/quickshell
  hl.exec_cmd("xsettingsd")
  hl.exec_cmd("wl-paste --watch cliphist store")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("fcitx5 -d")
  hl.exec_cmd("obsidian", { workspace = "5 silent" }) -- vault ~/obsidian-mind; its CLI needs the app running
  hl.exec_cmd("anki", { workspace = "5 silent" }) -- for flashcards, its CLI needs the app running
  hl.exec_cmd("[ -e /etc/NIXOS ] || hyprpm reload")
end)
