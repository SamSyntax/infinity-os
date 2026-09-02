#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RUNTIME_ROOT="$REPO_DIR/.runtime/nested"
MODE="interactive"
INITIAL_THEME="signal-archive"
STARTUP_TIMEOUT=20

usage() {
  cat <<'EOF'
Usage: ./launch-nested.sh [--smoke] [--theme THEME] [--timeout SECONDS]

Launch Infinity in a nested Hyprland session using repository-local state.

  --smoke            Run workspace, theme, renderer, and process checks, then exit.
  --theme THEME      Initial theme to deploy (default: signal-archive).
  --timeout SECONDS  Startup timeout (default: 20).
  --help             Show this help.

This command never needs root. Runtime state and logs stay under .runtime/nested/.
EOF
}

die() {
  printf 'infinity nested: %s\n' "$*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --smoke)
      MODE="smoke"
      shift
      ;;
    --theme)
      (($# >= 2)) || die "--theme requires a value"
      INITIAL_THEME=$2
      shift 2
      ;;
    --timeout)
      (($# >= 2)) || die "--timeout requires a value"
      STARTUP_TIMEOUT=$2
      [[ $STARTUP_TIMEOUT =~ ^[1-9][0-9]*$ ]] || die "timeout must be a positive integer"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

((EUID != 0)) || die "refusing to run a desktop session as root"
for command in Hyprland cmp cut dbus-run-session hyprctl quickshell python3 sha256sum setsid; do
  command -v "$command" >/dev/null 2>&1 || die "required command is missing: $command"
done

HOST_HOME=$HOME
HOST_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
HOST_WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
if [[ $HOST_WAYLAND_DISPLAY == /* ]]; then
  HOST_WAYLAND_SOCKET=$HOST_WAYLAND_DISPLAY
else
  HOST_WAYLAND_SOCKET="$HOST_RUNTIME_DIR/$HOST_WAYLAND_DISPLAY"
fi
HOST_HYPR_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-}
HOST_THEME_FILE="$HOST_HOME/.config/quickshell/generated/theme.json"
[[ -S $HOST_WAYLAND_SOCKET ]] || die "host Wayland socket is unavailable: $HOST_WAYLAND_SOCKET"

mkdir -p "$RUNTIME_ROOT"
RUN_DIR=$(mktemp -d "$RUNTIME_ROOT/run.XXXXXX")
SANDBOX_ROOT="$RUN_DIR/root"
MOCK_USER=${USER:-$(id -un)}
SANDBOX_HOME="$SANDBOX_ROOT/home/$MOCK_USER"
SANDBOX_RUNTIME_STORAGE="$RUN_DIR/runtime"
HYPR_LOG="$RUN_DIR/hyprland.log"
QUICKSHELL_LOG="$RUN_DIR/quickshell.log"
SYSTEM_INFO="$RUN_DIR/systeminfo.txt"

mkdir -p \
  "$SANDBOX_HOME/.config" \
  "$SANDBOX_HOME/.local/share" \
  "$SANDBOX_HOME/.local/state" \
  "$SANDBOX_HOME/.cache" \
  "$SANDBOX_RUNTIME_STORAGE"
chmod 700 "$SANDBOX_RUNTIME_STORAGE"
exec {RUNTIME_FD}<"$SANDBOX_RUNTIME_STORAGE"
SANDBOX_RUNTIME_DIR="/proc/$$/fd/$RUNTIME_FD"
SANDBOX_WAYLAND_LINK=""
if [[ $HOST_WAYLAND_DISPLAY != /* ]]; then
  SANDBOX_WAYLAND_LINK="$SANDBOX_RUNTIME_STORAGE/$HOST_WAYLAND_DISPLAY"
  ln -s "$HOST_WAYLAND_SOCKET" "$SANDBOX_WAYLAND_LINK"
fi

hash_file() {
  local path=$1
  if [[ -f $path && ! -L $path ]]; then
    sha256sum -- "$path" | cut -d' ' -f1
  else
    printf '%s\n' "missing"
  fi
}

host_workspace() {
  if [[ -z $HOST_HYPR_SIGNATURE ]]; then
    printf '%s\n' "unavailable"
    return
  fi
  XDG_RUNTIME_DIR="$HOST_RUNTIME_DIR" hyprctl -i "$HOST_HYPR_SIGNATURE" -j activeworkspace 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' 2>/dev/null \
    || printf '%s\n' "unavailable"
}

HOST_WORKSPACE_BEFORE=$(host_workspace)
HOST_THEME_BEFORE=$(hash_file "$HOST_THEME_FILE")
printf '%s\n' "$HOST_WORKSPACE_BEFORE" >"$RUN_DIR/host-workspace-before.txt"
printf '%s\n' "$HOST_THEME_BEFORE" >"$RUN_DIR/host-theme-before.sha256"

"$REPO_DIR/bin/infinity-deploy" --scope user --target-root "$SANDBOX_ROOT" --target-user "$MOCK_USER"
"$REPO_DIR/bin/infinity-theme" apply "$INITIAL_THEME" --target-root "$SANDBOX_ROOT" --target-user "$MOCK_USER"

unset HYPRLAND_INSTANCE_SIGNATURE
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_SESSION_ID
unset XDG_ACTIVATION_TOKEN
unset __GLX_VENDOR_LIBRARY_NAME
unset LIBVA_DRIVER_NAME

export HOME="$SANDBOX_HOME"
export USER="$MOCK_USER"
export LOGNAME="$MOCK_USER"
export XDG_CONFIG_HOME="$SANDBOX_HOME/.config"
export XDG_DATA_HOME="$SANDBOX_HOME/.local/share"
export XDG_STATE_HOME="$SANDBOX_HOME/.local/state"
export XDG_CACHE_HOME="$SANDBOX_HOME/.cache"
export XDG_RUNTIME_DIR="$SANDBOX_RUNTIME_DIR"
export WAYLAND_DISPLAY="$HOST_WAYLAND_DISPLAY"
export PATH="$SANDBOX_HOME/.local/bin:$PATH"
export INFINITY_THEME_COMMAND="$REPO_DIR/bin/infinity-theme"
export INFINITY_TARGET_ROOT="$SANDBOX_ROOT"
export INFINITY_NESTED="1"
export AQ_NO_MODIFIERS=1

HYPR_PID=""
cleanup() {
  local status=$?
  local process_group_stopped=true
  trap - EXIT INT TERM
  if [[ -n $HYPR_PID ]]; then
    kill -TERM -- "-$HYPR_PID" 2>/dev/null || true
    for _ in {1..50}; do
      kill -0 -- "-$HYPR_PID" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 -- "-$HYPR_PID" 2>/dev/null; then
      kill -KILL -- "-$HYPR_PID" 2>/dev/null || true
      sleep 0.1
    fi
    if kill -0 -- "-$HYPR_PID" 2>/dev/null; then
      process_group_stopped=false
      ((status == 0)) && status=1
    fi
    wait "$HYPR_PID" 2>/dev/null || true
  fi
  if [[ -n $SANDBOX_WAYLAND_LINK ]]; then
    rm -f -- "$SANDBOX_WAYLAND_LINK"
  fi
  printf 'exit_status=%s\nprocess_group_stopped=%s\n' "$status" "$process_group_stopped" >"$RUN_DIR/cleanup-status.txt"
  if ((status != 0)); then
    printf 'infinity nested: failed; logs retained in %s\n' "$RUN_DIR" >&2
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

setsid dbus-run-session -- Hyprland --config "$SANDBOX_HOME/.config/hypr/hyprland.lua" >"$HYPR_LOG" 2>&1 &
HYPR_PID=$!

NESTED_SIGNATURE=""
IPC_READY=0
deadline=$((SECONDS + STARTUP_TIMEOUT))
while ((SECONDS < deadline)); do
  kill -0 "$HYPR_PID" 2>/dev/null || die "Hyprland exited during startup; inspect $HYPR_LOG"
  shopt -s nullglob
  runtime_entries=("$SANDBOX_RUNTIME_STORAGE/hypr"/*)
  shopt -u nullglob
  candidates=()
  for candidate in "${runtime_entries[@]}"; do
    [[ -d $candidate ]] && candidates+=("$candidate")
  done
  if ((${#candidates[@]} == 1)) && [[ -d ${candidates[0]} ]]; then
    NESTED_SIGNATURE=${candidates[0]##*/}
    if hyprctl -i "$NESTED_SIGNATURE" status >/dev/null 2>&1; then
      IPC_READY=1
      break
    fi
  elif ((${#candidates[@]} > 1)); then
    die "ambiguous nested Hyprland instances under $SANDBOX_RUNTIME_STORAGE/hypr"
  fi
  sleep 0.1
done
((IPC_READY == 1)) || die "nested Hyprland IPC was not ready within ${STARTUP_TIMEOUT}s"

nested_ctl() {
  hyprctl -i "$NESTED_SIGNATURE" "$@"
}

printf 'infinity nested: run directory: %s\n' "$RUN_DIR"
printf 'infinity nested: instance: %s\n' "$NESTED_SIGNATURE"

if [[ $MODE == "interactive" ]]; then
  printf 'infinity nested: Hyprland log: %s\n' "$HYPR_LOG"
  wait "$HYPR_PID"
  exit $?
fi

if ! CONFIG_ERRORS=$(nested_ctl configerrors 2>&1); then
  die "unable to query nested Hyprland config errors: $CONFIG_ERRORS"
fi
[[ -z $CONFIG_ERRORS ]] || die "nested Hyprland reported config errors: $CONFIG_ERRORS"

if ! nested_ctl systeminfo >"$SYSTEM_INFO"; then
  die "unable to query nested renderer information"
fi
SYSTEM_INFO_LOWER=${SYSTEM_INFO,,}
[[ $SYSTEM_INFO_LOWER != *llvmpipe* && $SYSTEM_INFO_LOWER != *softpipe* ]] || die "nested renderer fell back to software; inspect $SYSTEM_INFO"

QUICKSHELL_INSTANCES=""
deadline=$((SECONDS + STARTUP_TIMEOUT))
while ((SECONDS < deadline)); do
  QUICKSHELL_INSTANCES=$(quickshell list --all --json 2>/dev/null || true)
  if python3 -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if len(data) == 1 else 1)' <<<"$QUICKSHELL_INSTANCES" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
python3 -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if len(data) == 1 else 1)' <<<"$QUICKSHELL_INSTANCES" \
  || die "expected exactly one sandbox Quickshell instance"
quickshell log --tail 500 --newest --any-display >"$QUICKSHELL_LOG" 2>&1 || true

if ! nested_ctl -j binds >"$RUN_DIR/binds.json"; then
  die "unable to query nested workspace bindings"
fi
python3 - "$RUN_DIR/binds.json" <<'PY' || die "nested workspace bindings are incomplete"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    bindings = json.load(handle)
actual = {(item.get("modmask"), str(item.get("key")), item.get("description")) for item in bindings}
for workspace in range(1, 10):
    key = str(workspace)
    if (64, key, f"Switch to workspace {key}") not in actual:
        raise SystemExit(1)
    if (65, key, f"Move window to workspace {key}") not in actual:
        raise SystemExit(1)
PY

if ! DISPATCH_OUTPUT=$(nested_ctl dispatch 'hl.dsp.focus({ workspace = "2" })' 2>&1); then
  die "nested workspace dispatch failed: $DISPATCH_OUTPUT"
fi
if ! ACTIVE_WORKSPACE=$(nested_ctl -j activeworkspace | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])'); then
  die "nested active workspace query failed"
fi
[[ $ACTIVE_WORKSPACE == "2" ]] || die "nested workspace dispatch selected $ACTIVE_WORKSPACE instead of 2"
printf '%s\n' "$ACTIVE_WORKSPACE" >"$RUN_DIR/nested-active-workspace.txt"

SANDBOX_THEME_FILE="$SANDBOX_HOME/.config/quickshell/generated/theme.json"
hash_file "$SANDBOX_THEME_FILE" >"$RUN_DIR/theme-before.sha256"
SMOKE_THEME="aurora"
[[ $INITIAL_THEME == "$SMOKE_THEME" ]] && SMOKE_THEME="signal-archive"
if ! "$REPO_DIR/bin/infinity-theme" apply "$SMOKE_THEME" --target-root "$SANDBOX_ROOT" --target-user "$MOCK_USER"; then
  die "sandbox theme application failed for $SMOKE_THEME"
fi
hash_file "$SANDBOX_THEME_FILE" >"$RUN_DIR/theme-after.sha256"
cmp -s "$RUN_DIR/theme-before.sha256" "$RUN_DIR/theme-after.sha256" && die "sandbox theme did not change"
python3 - "$SANDBOX_THEME_FILE" "$SMOKE_THEME" <<'PY' || die "sandbox theme state did not reload to the requested theme"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    theme = json.load(handle)
raise SystemExit(0 if theme.get("themeId") == sys.argv[2] else 1)
PY
sleep 0.5
quickshell log --tail 500 --newest --any-display >"$QUICKSHELL_LOG" 2>&1 || true
grep -Fq "Infinity theme loaded: $SMOKE_THEME" "$QUICKSHELL_LOG" || die "Quickshell did not report loading theme $SMOKE_THEME"

kill -0 "$HYPR_PID" 2>/dev/null || die "Hyprland exited after theme application"
nested_ctl status >/dev/null || die "nested Hyprland IPC failed after theme application"
QUICKSHELL_INSTANCES=$(quickshell list --all --json 2>/dev/null || true)
python3 -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if len(data) == 1 else 1)' <<<"$QUICKSHELL_INSTANCES" \
  || die "Quickshell exited after theme application"

HOST_THEME_AFTER=$(hash_file "$HOST_THEME_FILE")
[[ $HOST_THEME_AFTER == "$HOST_THEME_BEFORE" ]] || die "nested theme apply changed the host theme file"
HOST_WORKSPACE_AFTER=$(host_workspace)
[[ $HOST_WORKSPACE_AFTER == "$HOST_WORKSPACE_BEFORE" ]] || die "nested workspace dispatch changed the host workspace"
printf '%s\n' "$HOST_WORKSPACE_AFTER" >"$RUN_DIR/host-workspace-after.txt"
printf '%s\n' "$HOST_THEME_AFTER" >"$RUN_DIR/host-theme-after.sha256"

printf 'ok: nested Hyprland and Quickshell survived targeted workspace and theme checks\n'
printf 'ok: host workspace and theme state remained unchanged\n'
printf 'ok: renderer is hardware-backed; details in %s\n' "$SYSTEM_INFO"
