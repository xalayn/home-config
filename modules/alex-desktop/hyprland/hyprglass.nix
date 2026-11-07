# HyprGlass: Liquid Glass style blur, refraction and highlights for Hyprland.
# https://github.com/hyprnux/hyprglass
#
# Built from the branch for our Hyprland version (hyprland-0.57), against the
# exact Hyprland the system runs. To update: change `rev`, set
# `hash = lib.fakeHash;`, rebuild, and copy the hash from the error message.
{
  lib,
  fetchFromGitHub,
  hyprlandPlugins,
  pkg-config,
  wayland-scanner,
  wayland,
}:
hyprlandPlugins.mkHyprlandPlugin (finalAttrs: {
  pluginName = "hyprglass";
  version = "1.1.1-unstable-2026-11-03";

  src = fetchFromGitHub {
    owner = "hyprnux";
    repo = "hyprglass";
    rev = "dc00c628623e5e504b363e26dd489ee766d2fa12"; # branch hyprland-0.57
    hash = "sha256-z1ICVfSHI+6MqG0eybXXGCtetwAaPj5yeRbJEzZCxGo=";
  };

  nativeBuildInputs = [pkg-config wayland-scanner];
  buildInputs = [wayland];

  dontUseCmakeConfigure = true;
  dontUseMesonConfigure = true;
  enableParallelBuilding = true;

  makeFlags = ["HYPRGLASS_VERSION=${finalAttrs.version}"];

  installPhase = ''
    runHook preInstall
    install -Dm755 hyprglass.so "$out/lib/libhyprglass.so"
    runHook postInstall
  '';

  meta = {
    description = "Liquid Glass inspired blur and refraction for Hyprland";
    homepage = "https://github.com/hyprnux/hyprglass";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
})
