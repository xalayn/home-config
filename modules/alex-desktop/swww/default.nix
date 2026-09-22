{ lib, ... }:
{
  services.swww = {
    enable = true;
  };

  # Home Manager's swww module now uses awww and defaults to Restart=always.
  # Keep crash recovery, but do not resurrect awww after an intentional SIGTERM.
  systemd.user.services.awww.Service.Restart = lib.mkForce "on-failure";
}
