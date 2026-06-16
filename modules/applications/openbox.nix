{ pkgs, ... }:
{
  home.packages = with pkgs; [
    openbox
  ];
}
