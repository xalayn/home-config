{
  config,
  lib,
  pkgs,
  ...
}: {
  options.alex-desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland configuration";
  };

  config = lib.mkIf config.alex-desktop.hyprland.enable {
    # Hyprland itself is installed by the system config (programs.hyprland).
    # Hyprland reads ~/.config/hypr/hyprland.lua and reloads it on change.
    home.file.".config/hypr" = {
      source = ./dotfiles;
      recursive = true; # link recursively
    };

    home.packages = [pkgs.playerctl];
  };
}
