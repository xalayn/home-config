{ pkgs, inputs, ... }:
{
  home.packages = [ 
    inputs.twwh3-profile.packages.${pkgs.system}.twwh3-profile
    inputs.twwh3-profile.packages.${pkgs.system}.twwh3-mods
  ];
}