#!/usr/bin/env bash

set -euo pipefail

# The pinned repo contains system-config and home-config as git submodules,
# so one window covers everything.
flake_path="$HOME/Documents/nix-configs/pinned-nix-configs"

if [[ ! -f "$flake_path/flake.nix" ]]; then
    printf 'Pinned flake not found: %s\n' "$flake_path" >&2
    exit 1
fi

# Check out the submodules if this is a fresh clone.
git -C "$flake_path" submodule update --init

code --new-window "$flake_path" &
