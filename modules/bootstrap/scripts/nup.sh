#!/usr/bin/env bash

set -euo pipefail

flake_path="$HOME/Documents/nix-configs/pinned-nix-configs"
flake_host="alex-laptop"
flake_home="alex"

usage() {
    cat <<'EOF'
Usage: nix-update [options]

Options:
  -s    Rebuild only the system configuration
  -h    Rebuild only the Home Manager configuration
  -a    Rebuild both (the default)
  -f    Update the shared flake lock (the default)
  -n    Do not update the shared flake lock
  -p    Pause before exiting (used by the desktop launcher)
  -?    Show this help
EOF
}

do_system=false
do_home=false
do_flake=true
pause_on_exit=false
OPTERR=0

while getopts "shfanp" option; do
    case "$option" in
        s) do_system=true ;;
        h) do_home=true ;;
        f) do_flake=true ;;
        n) do_flake=false ;;
        a) do_system=true; do_home=true ;;
        p) pause_on_exit=true ;;
        ?) usage; exit 0 ;;
    esac
done

pause_before_exit() {
    local status=$?
    trap - EXIT
    printf '\n'
    read -r -p "Press Enter to close this window..." || true
    exit "$status"
}

if $pause_on_exit; then
    trap pause_before_exit EXIT
fi

if ! $do_system && ! $do_home; then
    do_system=true
    do_home=true
fi

if [[ ! -f "$flake_path/flake.nix" ]]; then
    printf 'Pinned flake not found: %s\n' "$flake_path" >&2
    exit 1
fi

cd "$flake_path"

if $do_flake; then
    printf '\n%s\n' '🔄 Updating the shared flake lock...'
    nix flake update
    printf '%s\n' '✅ Shared flake lock updated.'
fi

if $do_system; then
    printf '\n🔨 Rebuilding system configuration %s...\n' "$flake_host"
    sudo nixos-rebuild switch --flake ".#$flake_host"
    printf '%s\n' '✅ System configuration activated.'
fi

if $do_home; then
    printf '\n🔨 Rebuilding Home Manager configuration %s...\n' "$flake_home"
    home-manager switch --flake ".#$flake_home"
    printf '%s\n' '✅ Home Manager configuration activated.'
fi

printf '\n%s\n' '🎉 Update complete.'
if ! git diff --quiet -- flake.lock; then
    printf '%s\n' 'The pinned flake.lock changed and is ready to review and commit.'
fi
