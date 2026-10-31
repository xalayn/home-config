{ pkgs, ... }:
let
  # Discord's voice engine decodes H.264 streams with the OpenH264 2.5.1 (ABI 7)
  # library from its asset cache, but the client's "OpenH264 cleanup" replaces it
  # with 2.7.0 (ABI 8) and deletes it, so streams from other people fail with error
  # 2012. Only Cisco's exact 2.5.1 binary works (nixpkgs' 2.6.0 does not), so keep it
  # in place for both the nixpkgs and Flatpak clients.
  openh264Name = "libopenh264-2.5.1-linux64.7.so";
  openh264 = pkgs.runCommand openh264Name {
    src = pkgs.fetchurl {
      url = "http://ciscobinary.openh264.org/${openh264Name}.bz2";
      hash = "sha256-guQ224YGQz4/gjx//zJpxDs7o/ElEKhR73sVa4CtGxE=";
    };
  } "${pkgs.bzip2}/bin/bunzip2 -c $src > $out";

  cacheDirs = [
    "%h/.config/discord/discord_asset_cache/openh264"
    "%h/.var/app/com.discordapp.Discord/config/discord/discord_asset_cache/openh264"
  ];

  # Copied rather than symlinked: the Flatpak sandbox cannot follow links into /nix/store.
  restoreOpenh264 = pkgs.writeShellScript "discord-openh264-restore" ''
    for dir in "$@"; do
      [ -d "$dir" ] || continue
      ${pkgs.diffutils}/bin/cmp -s ${openh264} "$dir/${openh264Name}" \
        || ${pkgs.coreutils}/bin/install -m 0644 ${openh264} "$dir/${openh264Name}"
    done
  '';
in
{
  home.packages = with pkgs; [
    discord
  ];

  systemd.user.services.discord-openh264 = {
    Unit = {
      Description = "Keep Discord's OpenH264 2.5.1 library in place";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${restoreOpenh264} ${toString cacheDirs}";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.paths.discord-openh264 = {
    Unit = {
      Description = "Watch Discord's OpenH264 cache";
    };

    Path = {
      PathChanged = cacheDirs;
      MakeDirectory = true;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
