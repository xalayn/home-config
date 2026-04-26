{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.xalaynix-wrappers.wezterm
  ];
}
