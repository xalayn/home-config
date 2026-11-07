{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.xalaynix-wrappers.packages.${pkgs.system}.wezterm
    # the wrapper's zsh config aliases ls/ll/la to eza but doesn't ship it
    pkgs.eza
  ];
}
