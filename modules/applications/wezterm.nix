{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.xalaynix-wrappers.packages.${pkgs.system}.wezterm
  ];
}
