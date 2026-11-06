#!/usr/bin/env bash

set -euo pipefail

flake_path="$HOME/Documents/nix-configs/pinned-nix-configs"
flake_host="alex-laptop"
flake_home="alex"

# Config repos pinned as git submodules of the pinned flake.
config_repos=(system-config home-config)

usage() {
    cat <<'EOF_USAGE'
Usage: nix-update [options]

Options:
  -s    Rebuild only the system configuration
  -h    Rebuild only the Home Manager configuration
  -a    Rebuild both (the default)
  -f    Pull the config submodules and update the flake lock (the default)
  -c    Pull only the config submodules; keep the flake lock as is
  -n    Pull nothing; build the configs as they are checked out
  -p    Pause before exiting (used by the desktop launcher)
  -?    Show this help

The configs are built from the submodules inside the pinned repo,
including any uncommitted edits made there.
EOF_USAGE
}

do_system=false
do_home=false
do_pull=true
do_flake=true
pause_on_exit=false
OPTERR=0

while getopts "shfcanp" option; do
    case "$option" in
        s) do_system=true ;;
        h) do_home=true ;;
        f) do_pull=true; do_flake=true ;;
        c) do_pull=true; do_flake=false ;;
        n) do_pull=false; do_flake=false ;;
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

# Fast-forward a submodule's main branch to origin, keeping local work.
pull_submodule() {
    local name="$1" dir="$flake_path/$1"

    git -C "$dir" fetch --quiet origin

    # Fresh clones leave submodules detached; edits need a real branch.
    if ! git -C "$dir" symbolic-ref --quiet HEAD >/dev/null; then
        git -C "$dir" checkout --quiet main
    fi

    if ! git -C "$dir" merge --quiet --ff-only '@{u}'; then
        printf '⚠️  %s could not fast-forward (diverged from origin or conflicting edits); left as is.\n' "$name"
    fi

    local ahead
    ahead=$(git -C "$dir" rev-list --count '@{u}..HEAD')
    if ((ahead > 0)); then
        printf 'ℹ️  %s has %s unpushed commit(s).\n' "$name" "$ahead"
    fi
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
        printf 'ℹ️  %s has uncommitted changes (they will be built).\n' "$name"
    fi
}

cd "$flake_path"

# Check out the submodules if this is a fresh clone.
git submodule update --init

if $do_pull; then
    printf '\n%s\n' '🔄 Pulling config submodules...'
    for repo in "${config_repos[@]}"; do
        pull_submodule "$repo"
    done
    printf '%s\n' '✅ Config submodules up to date.'
fi

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
if [[ -n "$(git status --porcelain -- flake.lock "${config_repos[@]}")" ]]; then
    printf '%s\n' 'The pinned flake.lock and/or config submodules changed and are ready to review and commit:'
    git status --short -- flake.lock "${config_repos[@]}"
fi
