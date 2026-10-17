#!/bin/sh
# A fastfetch module's output, without the wait: `cached.sh packages` or `cached.sh wm`, run from a
# command module in config.jsonc. The line is kept under a key that changes exactly when the answer
# does, so a hit costs a few readlinks. On a miss the last line is shown and fastfetch recomputes it
# in the background for next time.
#   packages: fastfetch runs `nix-store --query --hash` on every profile to validate its own cache
#             (~0.25s) and re-walks every closure after a rebuild (~1.3s). Key: the profiles'
#             resolved store paths.
#   wm:       fastfetch runs `Hyprland --version` (~0.2s). Key: the running Hyprland's store path,
#             from its command line (/proc/<pid>/exe is unreadable behind the capability wrapper).

module=$1
case $module in
packages)
    key=$(readlink -f /run/current-system /etc/profiles/per-user/"$USER" "$HOME/.nix-profile" \
        "$HOME/.local/state/nix/profile" 2>/dev/null | paste -sd ' ' -)
    ;;
wm)
    pid=$(head -n 1 "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.lock" 2>/dev/null)
    key=$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | head -n 1)
    ;;
*)
    echo "cached.sh: unknown module '$module'" >&2
    exit 1
    ;;
esac

cache="${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch/$module-line"

compute() {
    fastfetch --config none --logo none --pipe true -s "$module" | sed 's/^[^:]*: *//'
}

if [ -f "$cache" ]; then
    { read -r cached_key; read -r line; } <"$cache"
    printf '%s\n' "$line"
    [ -n "$key" ] && [ "$cached_key" = "$key" ] && exit 0
    # stale: refresh in the background, detached so fastfetch doesn't wait for it
    (line=$(compute) && [ -n "$line" ] && printf '%s\n%s\n' "$key" "$line" >"$cache.tmp" && mv "$cache.tmp" "$cache") \
        </dev/null >/dev/null 2>&1 &
    exit 0
fi

# first run: nothing to show yet, so compute now
mkdir -p "$(dirname "$cache")"
line=$(compute)
printf '%s\n' "$line"
[ -n "$line" ] && printf '%s\n%s\n' "$key" "$line" >"$cache"
