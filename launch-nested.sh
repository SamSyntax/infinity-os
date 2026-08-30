#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SANDBOX_ROOT="/tmp/infinity-sandbox"
MOCK_USER="$USER"
SANDBOX_HOME="$SANDBOX_ROOT/home/$MOCK_USER"

# Capture host variables before we isolate
HOST_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HOST_WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
SANDBOX_RUNTIME_DIR="$HOST_RUNTIME_DIR/nested-hypr"

mkdir -p "$SANDBOX_HOME/.config" "$SANDBOX_HOME/.local/share" "$SANDBOX_ROOT"
mkdir -p "$SANDBOX_RUNTIME_DIR"
chmod 700 "$SANDBOX_RUNTIME_DIR"

# Magic step: Symlink the host's Wayland socket into the sandbox so Aquamarine can connect
ln -sf "$HOST_RUNTIME_DIR/$HOST_WAYLAND_DISPLAY" "$SANDBOX_RUNTIME_DIR/$HOST_WAYLAND_DISPLAY"

"$REPO_DIR/bin/infinity-deploy" --scope user --target-root "$SANDBOX_ROOT" --target-user "$MOCK_USER"
"$REPO_DIR/bin/infinity-theme" apply signal-archive --target-root "$SANDBOX_ROOT" --target-user "$MOCK_USER"

hyprctl dispatch workspace 5 >/dev/null 2>&1 || true

# Strip ALL host identifiers
unset HYPRLAND_INSTANCE_SIGNATURE
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_SESSION_ID
unset XDG_ACTIVATION_TOKEN

# Enforce strict sandbox paths
export HOME="$SANDBOX_HOME"
export XDG_CONFIG_HOME="$SANDBOX_HOME/.config"
export XDG_DATA_HOME="$SANDBOX_HOME/.local/share"
export XDG_STATE_HOME="$SANDBOX_HOME/.local/state"
export XDG_CACHE_HOME="$SANDBOX_HOME/.cache"
export XDG_RUNTIME_DIR="$SANDBOX_RUNTIME_DIR"
export INFINITY_THEME_COMMAND="$REPO_DIR/bin/infinity-theme"
export AQ_NO_MODIFIERS=1

# Run with an isolated DBus daemon
exec dbus-run-session Hyprland --config "$SANDBOX_HOME/.config/hypr/hyprland.lua"
