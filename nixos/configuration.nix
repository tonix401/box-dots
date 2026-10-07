# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

let
  hyprexpo = pkgs.callPackage (pkgs.fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    rev = "a54d20e433831eb9a5770e052c48736421ba7db5";
    hash = "sha256-L3QG1HvO2tdaAgYrOxaiqn/NXs9kECHEP78h2+8pZ6A=";
  }) { };

  # Same look as the Arch box: the post-apocalyptic_hacker preset with its colors fixed (not
  # matugen) and the background following the current wallpaper.
  sddmTheme = pkgs.sddm-astronaut.override {
    embeddedTheme = "post-apocalyptic_hacker";
    themeConfig = {
      ScreenWidth = "1920";
      ScreenHeight = "1080";
      Font = "JetBrainsMono Nerd Font";
      FontSize = "15";
      KeyboardSize = "0.4";
      RoundCorners = "10";
      HourFormat = "HH:mm";
      DateFormat = "dddd d";
      Background = "/home/tom/.cache/box-dots/current/wallpaper.png";
      DimBackground = "0.0";
      CropBackground = "true";
      BackgroundHorizontalAlignment = "center";
      BackgroundVerticalAlignment = "center";
      HeaderTextColor = "#ffffff";
      DateTextColor = "#ffffff";
      TimeTextColor = "#ffffff";
      FormBackgroundColor = "#000000";
      BackgroundColor = "#000000";
      DimBackgroundColor = "#000000";
      LoginFieldBackgroundColor = "#000000";
      PasswordFieldBackgroundColor = "#000000";
      LoginFieldTextColor = "#ffffff";
      PasswordFieldTextColor = "#ffffff";
      UserIconColor = "#ffffff";
      PasswordIconColor = "#ffffff";
      PlaceholderTextColor = "#cccccc";
      WarningColor = "#fc2e64";
      LoginButtonTextColor = "#ffffff";
      LoginButtonBackgroundColor = "#000000";
      SystemButtonsIconsColor = "#ffffff";
      SessionButtonTextColor = "#ffffff";
      VirtualKeyboardButtonTextColor = "#ffffff";
      DropdownTextColor = "#ffffff";
      DropdownSelectedBackgroundColor = "#4d1927";
      DropdownBackgroundColor = "#32141f";
      HighlightTextColor = "#ffffff";
      HighlightBackgroundColor = "#4d1927";
      HighlightBorderColor = "#4d1927";
      HoverUserIconColor = "#fc2e64";
      HoverPasswordIconColor = "#fc2e64";
      HoverSystemButtonsIconsColor = "#fc2e64";
      HoverSessionButtonTextColor = "#fc2e64";
      HoverVirtualKeyboardButtonTextColor = "#fc2e64";
      HaveFormBackground = "false";
      FormPosition = "center";
      VirtualKeyboardPosition = "right";
      HideVirtualKeyboard = "true";
      HideSystemButtons = "false";
      HideLoginButton = "false";
      ForceLastUser = "true";
      PasswordFocus = "true";
      HideCompletePassword = "true";
      AllowEmptyPassword = "false";
      AllowUppercaseLettersInUsernames = "false";
      BypassSystemButtonsChecks = "false";
      RightToLeftLayout = "false";
    };
  };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <home-manager/nixos>
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;
  # iwd backend so iwctl/iwgtk from the quickshell bar work
  networking.networkmanager.wifi.backend = "iwd";

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  users.users.tom = {
    isNormalUser = true;
    description = "tom";
    extraGroups = [ "networkmanager" "wheel" "i2c" ];
    # Lets the sddm user reach the wallpaper in ~/.cache (traverse only, no listing)
    homeMode = "711";
    shell = pkgs.fish;
  };

  # Dotfiles and user packages live in home.nix
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.tom = import ./home.nix;
  };

  nixpkgs.config.allowUnfree = true;

  # Desktop
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "sddm-astronaut-theme";
    extraPackages = [ sddmTheme ];
    settings.General.InputMethod = "qtvirtualkeyboard";
  };
  # The greeter's background is the wallpaper picked with SUPER+P (copied there by
  # hypr/scripts/helpers/update-current-wallpaper.py), so the sddm user must be able to get to it.
  systemd.tmpfiles.rules = [
    "d /home/tom/.cache 0711 tom users -"
    "d /home/tom/.cache/box-dots 0755 tom users -"
    "d /home/tom/.cache/box-dots/current 0755 tom users -"
  ];
  services.displayManager.defaultSession = "hyprland";

  programs.hyprland.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Loaded from ~/.config/hypr/hyprland.lua; replaces hyprpm on NixOS
  environment.etc."hypr/plugins/hyprexpo.so".source = "${hyprexpo}/lib/libhyprexpo.so";

  # Makes `systemctl --user start hyprpolkitagent` (hypr/exec.lua) work
  systemd.packages = [ pkgs.hyprpolkitagent ];

  programs.fish.enable = true;

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  # Audio (wpctl in keybinds and quickshell)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Bluetooth (quickshell: rfkill / blueman-manager)
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.power-profiles-daemon.enable = true;
  services.tailscale.enable = true;

  # Monitor brightness over DDC/CI (ddcutil in quickshell)
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    sddmTheme
    git
    chromium
    claude-code
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    adwaita-fonts # Adwaita Sans / Mono: the ui font in gtk and quickshell
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
