{
  config,
  lib,
  pkgs,
  ...
}: let
  # Relaunch the focused suspended window, or else the first suspended one
  driftwm-relaunch = pkgs.writeShellApplication {
    name = "driftwm-relaunch";
    runtimeInputs = [pkgs.jq];
    text = ''
      driftwm msg relaunch 2>/dev/null && exit 0
      id=$(driftwm msg state --json \
        | jq -r '[.Ok.State.windows[] | select(.suspended)][0].id // empty')
      [ -n "$id" ] && driftwm msg relaunch --id "$id"
    '';
  };
in {
  options.alex-desktop.driftwm = {
    enable = lib.mkEnableOption "driftwm configuration";
  };

  config = lib.mkIf config.alex-desktop.driftwm.enable {
    # driftwm reads ~/.config/driftwm/config.toml and reloads it on change
    home.file.".config/driftwm" = {
      source = ./dotfiles;
      recursive = true; # link recursively
    };

    home.packages = [driftwm-relaunch];
  };
}
