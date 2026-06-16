{ pkgs, ... }:
{
  home.packages = with pkgs; [
    xwayland
  ];
}
