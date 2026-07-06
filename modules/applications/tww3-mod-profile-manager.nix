{ pkgs, inputs, ... }:
{
  home.packages = [ inputs.twwh3-profile-manager.packages.${pkgs.system}.default ];
}