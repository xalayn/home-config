# edgeworkspaces: keeps niri's empty workspaces above the first and below the
# last workspace on each monitor ready ahead of time. Source: ./edgeworkspaces.
# Like any Hyprland plugin it must be built against the Hyprland that loads it.
{
  lib,
  hyprlandPlugins,
  lua5_4,
  pkg-config,
}:
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "edgeworkspaces";
  version = "1.0";
  src = ./edgeworkspaces;

  nativeBuildInputs = [pkg-config];
  buildInputs = [lua5_4];

  dontUseCmakeConfigure = true;
  dontUseMesonConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CXX -shared -fPIC -O2 -std=c++2b -Wno-narrowing main.cpp -o edgeworkspaces.so \
      $(pkg-config --cflags pixman-1 libdrm hyprland pangocairo libinput libudev wayland-server xkbcommon lua)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 edgeworkspaces.so "$out/lib/libedgeworkspaces.so"
    runHook postInstall
  '';

  meta = {
    description = "Keeps niri-style empty workspaces ready at both ends";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
