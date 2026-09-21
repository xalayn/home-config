{ pkgs-unstable, ... }:
{
  programs.floorp = {
    enable = true;
    package = pkgs-unstable.floorp-bin;
  };
}
