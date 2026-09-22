{
  config,
  pkgs,
  ...
}:
{
  home.file.".local/bin/nix-edit" = {
    source = ./ned.sh;
    executable = true;
  };

  home.file.".local/bin/nix-update" = {
    source = ./nup.sh;
    executable = true;
  };

  home.sessionPath = [ "$HOME/.local/bin" ];

  home.shellAliases = {
    ned = "nix-edit";
    nup = "nix-update";
  };

  # Written directly because this flake's Home Manager and Nixpkgs revisions
  # disagree about makeDesktopItem's removed extraConfig option.
  xdg.dataFile."applications/nix-config-edit.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Edit Nix Configuration
    GenericName=Nix Configuration Editor
    Comment=Open the Home Manager and NixOS configuration repositories
    Exec=${config.home.homeDirectory}/.local/bin/nix-edit
    Icon=visual-studio-code
    Terminal=false
    Categories=Settings;System;
  '';

  xdg.dataFile."applications/nix-config-update.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Update Nix System
    GenericName=Nix System Updater
    Comment=Update the shared pinned flake and rebuild NixOS and Home Manager
    Exec=${pkgs.ghostty}/bin/ghostty -e ${config.home.homeDirectory}/.local/bin/nix-update -p
    Icon=system-software-update
    Terminal=false
    Categories=Settings;System;
  '';
}
