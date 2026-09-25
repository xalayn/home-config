{ pkgs, ... }:
{
  home.packages = with pkgs; [
    sourcegit
  ];
}