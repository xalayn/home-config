# Phantomat: a zoomable, infinite-canvas window manager plugin for Hyprland.
# https://github.com/kaolti/phantomat
#
# A Hyprland plugin must be built against the exact Hyprland that loads it, so
# pass the same package the system uses (programs.hyprland.package).
# To update: change `rev`, set `hash = lib.fakeHash;`, rebuild, and copy the
# hash from the error message.
{
  lib,
  fetchFromGitHub,
  hyprland,
  hyprlandPlugins,
  lua5_4,
  pango,
  cairo,
}:
hyprlandPlugins.mkHyprlandPlugin (finalAttrs: {
  pluginName = "spatialoverview";
  version = "0-unstable-2026-10-08";

  src = fetchFromGitHub {
    owner = "kaolti";
    repo = "phantomat";
    rev = "a1e8a0806541640d01503ac861a8a39548de8724";
    hash = "sha256-s24hrCkfFub5oObSPA2W3Y+mzFiIK7exSaTB+UsPgbM=";
  };

  inherit hyprland;

  patches = [
    # Unmerged upstream PR #8: draw every canvas window through the same
    # direct-geometry path as the dragged one. Without it, previews of the
    # other windows could be drawn offset from their real positions whenever
    # zoom != 100%, so a window lined up against them landed elsewhere on exit.
    # Drop this once it is merged upstream.
    ./patches/pr8-preview-displacement.patch
  ];

  buildInputs = [lua5_4 pango cairo];

  dontUseCmakeConfigure = true;
  dontUseMesonConfigure = true;
  enableParallelBuilding = true;

  # The version header normally comes from `git rev-parse`.
  env.SCROLLOVERVIEW_BUILD_VERSION = builtins.substring 0 12 finalAttrs.src.rev;

  makeFlags = ["all"];

  installPhase = ''
    runHook preInstall
    install -Dm755 spatialoverview.so "$out/lib/libspatialoverview.so"
    install -Dm644 examples/spatialoverview.lua "$out/share/phantomat/spatialoverview.example.lua"
    runHook postInstall
  '';

  meta = {
    description = "Zoomable, infinite-canvas window manager for Hyprland";
    homepage = "https://github.com/kaolti/phantomat";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
})
