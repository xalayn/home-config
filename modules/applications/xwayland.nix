{ pkgs, ... }:
{
  home.packages = with pkgs; [
    xwayland
    xorg.xdpyinfo
    pkgs.xclip
    pkgs.wl-clipboard
  ];
}
