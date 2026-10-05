{ config, lib, pkgs, ... }:

let
  dots = "${config.home.homeDirectory}/box-dots";
  # Out-of-store links keep the files writable, so matugen can regenerate colors
  link = name: { source = config.lib.file.mkOutOfStoreSymlink "${dots}/${name}"; };
in
{
  home.username = "tom";
  home.homeDirectory = "/home/tom";
  home.stateVersion = "25.11";

  xdg.configFile = lib.genAttrs [
    "btop"
    "fastfetch"
    "fcitx5"
    "fish"
    "gtk-3.0"
    "gtk-4.0"
    "hypr"
    "kitty"
    "matugen"
    "quickshell"
    "starship.toml"
  ] link;

  programs.git = {
    enable = true;
    settings.user = {
      name = "tom";
      email = "tom.weise.2004@gmail.com";
    };
  };

  # Started by hypr/exec.lua once the Wayland environment is exported, so services that need
  # the session (graphical-session.target) can wait for it; plain Hyprland never starts it.
  systemd.user.targets.hyprland-session.Unit = {
    Description = "Hyprland session";
    BindsTo = [ "graphical-session.target" ];
    Wants = [ "graphical-session-pre.target" ];
    After = [ "graphical-session-pre.target" ];
  };

  # Dank Calendar, hidden in the background: the backend the quickshell widgets (WeekCalendar,
  # TodoList, HabitTracker) talk to over $XDG_RUNTIME_DIR/dankcal-<pid>.sock, and the window
  #  opens to add accounts. Same as the package's own unit, which can't be enabled here.
  systemd.user.services.dcal = {
    Unit = {
      Description = "Dank Calendar";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.dankcalendar}/bin/dcal run --session --hidden";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "app.slice";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  home.packages = with pkgs; [
    # hyprland ecosystem
    hyprlock
    hyprshutdown
    awww
    quickshell
    hyprpicker
    xsettingsd
    matugen
    adw-gtk3
    adwaita-icon-theme # the icon theme quickshell and gtk use

    # menus, clipboard, screenshots
    grimblast
    cliphist
    wtype
    wl-clipboard
    libnotify
    imagemagick
    librsvg
    # rofimoji's module provides the emoji data for quickshell/scripts/emoji.py
    (python3.withPackages (ps: [ ps.pyvips (ps.toPythonModule rofimoji) ]))

    # quickshell bar and menus
    jq
    ddcutil
    nemo
    dankcalendar
    pavucontrol
    iwgtk
    playerctl
    brightnessctl

    # terminal
    kitty
    starship
    fastfetch
    btop
    eza
    zoxide
    fzf
    fortune
    cowsay
    lolcat
  ];
}
