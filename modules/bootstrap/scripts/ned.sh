#!/usr/bin/env bash

set -euo pipefail

config_root="$HOME/Documents/nix-configs"
home_config="$config_root/home-config"
system_config="$config_root/system-config"

for config_dir in "$home_config" "$system_config"; do
    if [[ ! -d "$config_dir" ]]; then
        printf 'Config directory not found: %s\n' "$config_dir" >&2
        exit 1
    fi
done

code --new-window "$home_config" &
code --new-window "$system_config" &
