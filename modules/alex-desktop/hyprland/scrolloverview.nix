# ScrollOverview: a niri-like overview of your workspaces for Hyprland.
# https://github.com/yayuuu/hyprland-scroll-overview
#
# A Hyprland plugin must be built against the exact Hyprland that loads it, so
# pass the same package the system uses (programs.hyprland.package).
# Upstream's main branch tracks the latest Hyprland release.
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
  pluginName = "scrolloverview";
  version = "0-unstable-2026-11-01";

  # Pinned to the last commit before upstream's "hyprbars support refactor"
  # (PR #93, merged 2026-11-02). That refactor hooks Hyprland's renderRect /
  # renderTexture, and with nixpkgs' Hyprland 0.57.1 opening the overview
  # segfaults in those hooks (renderDecorationTexture, via a blurred rect).
  # Check that this is fixed upstream before moving past it.
  src = fetchFromGitHub {
    owner = "yayuuu";
    repo = "hyprland-scroll-overview";
    rev = "a8dcca6fe3ddc2164774cb6925bc67c0b974a78f";
    hash = "sha256-684XIZXg/MPkFClgTJGUAVB/bEc4C2aTdD/nfQEt81o=";
  };

  # Adds a "workspace" gesture action: inside the overview, a swipe scrolls
  # between workspaces under your fingers (as a two-finger scroll already
  # does); outside it, it's Hyprland's normal workspace swipe.
  patches = [./patches/scrolloverview-workspace-swipe.patch];

  inherit hyprland;

  buildInputs = [lua5_4 pango cairo];

  dontUseCmakeConfigure = true;
  dontUseMesonConfigure = true;
  enableParallelBuilding = true;

  # The version header normally comes from `git rev-parse`.
  env.SCROLLOVERVIEW_BUILD_VERSION = builtins.substring 0 12 finalAttrs.src.rev;

  makeFlags = ["all"];

  installPhase = ''
    runHook preInstall
    install -Dm755 scrolloverview.so "$out/lib/libscrolloverview.so"
    runHook postInstall
  '';

  meta = {
    description = "Niri-like scrollable workspace overview for Hyprland";
    homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
})
