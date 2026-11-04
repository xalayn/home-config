{
  config,
  lib,
  ...
}: {
  options.alex-desktop.driftwm = {
    enable = lib.mkEnableOption "driftwm configuration";
  };

  config = lib.mkIf config.alex-desktop.driftwm.enable {
    # driftwm reads ~/.config/driftwm/config.toml and reloads it on change
    home.file.".config/driftwm" = {
      source = ./dotfiles;
      recursive = true; # link recursively
    };
  };
}
