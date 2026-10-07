#!/usr/bin/env bash
# Copies the laptop's NixOS config from this folder to /etc/nixos and rebuilds with it.
#
# The config is built as the normal user first (no root needed), so one that doesn't evaluate or
# build never reaches /etc/nixos. hardware-configuration.nix is not copied: nixos-generate-config
# writes it on the machine, so /etc/nixos has the real one; a difference is only reported.
#
# Usage: nixos/apply.sh [-y] [switch|boot|test|build]
#   switch (default)  copy, then make it the running system and the boot default
#   boot              copy, then make it the boot default only
#   test              copy, then run it without making it the boot default
#   build             only build it as the user: nothing is copied, no sudo
#   -y                don't ask before copying
set -euo pipefail

src=$(cd "$(dirname "$0")" && pwd)
dst=/etc/nixos
files=(configuration.nix home.nix)

yes=0
if [[ ${1:-} == -y ]]; then
    yes=1
    shift
fi
action=${1:-switch}
case $action in
    switch | boot | test | build) ;;
    *)
        sed -n '8,13p' "$0" >&2
        exit 2
        ;;
esac

changed=()
for f in "${files[@]}"; do
    if ! cmp -s "$src/$f" "$dst/$f"; then
        changed+=("$f")
        diff -u --label "$dst/$f" --label "$src/$f" "$dst/$f" "$src/$f" || true
    fi
done
if ! cmp -s "$src/hardware-configuration.nix" "$dst/hardware-configuration.nix"; then
    echo "note: hardware-configuration.nix differs from $dst (not copied)" >&2
fi

# Builds in a scratch folder, which gets the ./result link.
echo ":: building $src/configuration.nix"
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
(cd "$build" && nixos-rebuild build -I nixos-config="$src/configuration.nix")
[[ $action == build ]] && exit 0

if ((${#changed[@]})); then
    if ((!yes)); then
        read -rp "Copy ${changed[*]} to $dst and $action? [y/N] " answer
        [[ $answer == [yY]* ]] || exit 1
    fi
    for f in "${changed[@]}"; do
        sudo install -m 644 -o root -g root "$src/$f" "$dst/$f"
    done
else
    echo ":: $dst is up to date"
fi

echo ":: nixos-rebuild $action"
sudo nixos-rebuild "$action"
