{ pkgs, config, ... }:
{
  imports = [
    ./niri
    ./driftwm
    ./hyprland
    ./wallpaper
    ./eww
    ./fuzzel
    ./swaybg
    ./mpvpaper
    ./waybar
    ./waypaper
    ./pavucontrol
    ./quickshell
    ./swww
    ./brightnessctl
    ./mako
  ];

  alex-desktop = {
    niri = {
      enable = true;
      wallpaperPath = config.alex-desktop.wallpaper;
    };
    driftwm.enable = true;
    hyprland.enable = true;
  };
}