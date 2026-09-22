{ ... }:
{
  programs.fuzzel = {
    enable = true;
    settings.main.terminal = "wezterm start --always-new-process --";
  };
}
