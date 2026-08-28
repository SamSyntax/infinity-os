#!/usr/bin/env bash
set -Eeuo pipefail

INFINITY_STAGES=(preflight repositories base hardware wayland desktop-shell applications services boot greeter themes deploy validate preview)
INFINITY_APPLY_STAGES=(preflight themes deploy validate preview)

infinity_usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --help                    Show this help.
  --plan, --dry-run         Print intended actions only.
  --confirm                 Required for non-dry-run apply.
  --target-root PATH        Target root, default /.
  --target-user USER        Target user, default current user.
  --stage NAME              Repeatable stage selection.

Stages:
  preflight,repositories,base,hardware,wayland,desktop-shell,applications,services,boot,greeter,themes,deploy,validate,preview

Apply-capable stages:
  preflight,themes,deploy,validate,preview

No disk partitioning is performed.
USAGE
}

infinity_die() {
  printf 'infinity install: %s\n' "$1" >&2
  exit 1
}

infinity_has_stage() {
  local wanted=$1 stage
  for stage in "${INFINITY_STAGES[@]}"; do
    [[ $stage == "$wanted" ]] && return 0
  done
  return 1
}

infinity_has_apply_stage() {
  local wanted=$1 stage
  for stage in "${INFINITY_APPLY_STAGES[@]}"; do
    [[ $stage == "$wanted" ]] && return 0
  done
  return 1
}

infinity_validate_apply_selection() {
  local unsupported=() stage has_preview=0 count=0
  for stage in "$@"; do
    count=$((count + 1))
    [[ $stage == preview ]] && has_preview=1
    infinity_has_apply_stage "$stage" || unsupported+=("$stage")
  done
  if ((${#unsupported[@]})); then
    infinity_die "selected stages are plan-only: ${unsupported[*]}; use --plan or select only preflight,themes,deploy,validate,preview"
  fi
  if [[ $has_preview == 1 && $count -ne 1 ]]; then
    infinity_die "preview apply must be selected by itself; run only --stage preview so deployment stays user-scoped"
  fi
}

infinity_log_append() {
  [[ $INFINITY_DRY_RUN == 1 ]] && return 0
  PYTHONPATH="$INFINITY_REPO/installation/lib" python3 - "$INFINITY_TARGET_ROOT" "$INFINITY_LOG" "$1" <<'PY'
import os
import sys
from pathlib import Path
from safe_fs import append_regular, resolve_root
root = resolve_root(sys.argv[1])
destination = Path(sys.argv[2])
if not destination.is_absolute():
    destination = Path(os.path.abspath(destination))
append_regular(root, destination, (sys.argv[3] + "\n").encode(), 0o644)
PY
}

infinity_log() {
  printf '%s\n' "$1"
  infinity_log_append "$1"
}

infinity_log_command() {
  local output status
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
  if [[ -n $output ]]; then
    printf '%s\n' "$output"
    [[ $INFINITY_DRY_RUN == 1 ]] || infinity_log_append "$output"
  fi
  return "$status"
}

infinity_manifest_packages() {
  local group=$1
  local file="$INFINITY_REPO/system/packages/$group.official.txt"
  [[ -f $file ]] || return 0
  python3 - "$file" <<'PY'
import os
import sys
for line in open(sys.argv[1], encoding='utf-8'):
    item=line.split('#',1)[0].strip()
    if item:
        print(item)
PY
}

infinity_preview_packages() {
  local file="$INFINITY_REPO/installation/preview-packages.official.txt"
  python3 - "$file" <<'PY'
import re
import sys
pattern = re.compile(r"^[a-z0-9@._+-]+$")
for line_no, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    item = line.split("#", 1)[0].strip()
    if not item:
        continue
    if not pattern.fullmatch(item):
        raise SystemExit(f"invalid preview package token at {sys.argv[1]}:{line_no}: {item!r}")
    print(item)
PY
}

infinity_install_preview_packages() {
  local packages=()
  mapfile -t packages < <(infinity_preview_packages)
  ((${#packages[@]})) || infinity_die "preview package manifest is empty"
  pacman -Syu --needed --noconfirm "${packages[@]}"
}

infinity_resolved_root() {
  python3 - "$1" <<'PY'
import sys
from pathlib import Path
print(Path(sys.argv[1]).resolve(strict=True))
PY
}

infinity_preview_preflight() {
  local resolved uid home
  resolved=$(infinity_resolved_root "$INFINITY_TARGET_ROOT") || infinity_die "cannot resolve target root '$INFINITY_TARGET_ROOT'"
  [[ $resolved == / ]] || infinity_die "preview apply only supports --target-root / on the running VM; got '$resolved'. Use --plan for other roots."
  [[ ${EUID:-$(id -u)} == 0 ]] || infinity_die "preview apply must run as root with sudo so pacman and user deployment can write to the VM"
  command -v pacman >/dev/null || infinity_die "preview apply requires pacman in PATH; run this on an already bootable Arch VM, not this development host or a non-Arch environment"
  getent passwd "$INFINITY_TARGET_USER" >/dev/null || infinity_die "target user '$INFINITY_TARGET_USER' does not exist on this VM"
  uid=$(getent passwd "$INFINITY_TARGET_USER" | cut -d: -f3)
  home=$(getent passwd "$INFINITY_TARGET_USER" | cut -d: -f6)
  [[ $uid =~ ^[0-9]+$ && $uid -ne 0 ]] || infinity_die "target user '$INFINITY_TARGET_USER' must be a non-root account"
  [[ $home == "/home/$INFINITY_TARGET_USER" ]] || infinity_die "target user '$INFINITY_TARGET_USER' home must be exactly /home/$INFINITY_TARGET_USER, got '$home'"
}

infinity_preview_success() {
  cat <<'PREVIEW'
PREVIEW READY
To launch manually from the VM:
  1. Log out of any graphical session or switch to a TTY with Ctrl+Alt+F3.
  2. Log in as the target user.
  3. Run: Hyprland --config "$HOME/.config/hypr/hyprland.lua"
Inside the preview:
  - Super+Return opens Ghostty.
  - Super+Shift+M exits Hyprland and returns to the TTY.
VM note: Hyprland may require working 3D acceleration in the VM.
PREVIEW
}

infinity_plan_packages() {
  local group=$1
  local pkgs
  pkgs=$(infinity_manifest_packages "$group" | paste -sd ' ' -)
  [[ -n $pkgs ]] && infinity_log "PLAN packages[$group]: $pkgs"
}

infinity_run_stage() {
  local stage=$1
  infinity_log "STAGE $stage"
  case "$stage" in
    preflight)
      [[ -d $INFINITY_TARGET_ROOT ]] || infinity_die "target root '$INFINITY_TARGET_ROOT' does not exist"
      [[ -n $INFINITY_TARGET_USER ]] || infinity_die "target user is empty"
      infinity_log "PLAN target-root=$INFINITY_TARGET_ROOT target-user=$INFINITY_TARGET_USER dry-run=$INFINITY_DRY_RUN"
      ;;
    repositories)
      infinity_log "PLAN enable official Arch repositories already configured by base system; no network bootstrap here"
      ;;
    base|hardware|wayland|desktop-shell|applications)
      infinity_plan_packages "$stage"
      ;;
    services)
      infinity_log "PLAN enable NetworkManager, bluetooth, power-profiles-daemon, greetd, pipewire user services where present"
      ;;
    boot)
      infinity_log "PLAN install systemd-boot/Plymouth templates from system/boot and system/plymouth after UUID review"
      ;;
    greeter)
      infinity_log "PLAN deploy greetd/ReGreet config with tuigreet recovery template"
      ;;
    themes)
      local theme_args=(apply nocturne --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER")
      [[ $INFINITY_DRY_RUN == 1 ]] && theme_args+=(--dry-run)
      infinity_log_command "$INFINITY_REPO/bin/infinity-theme" "${theme_args[@]}"
      ;;
    deploy)
      local deploy_args=(--target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER")
      [[ $INFINITY_DRY_RUN == 1 ]] && deploy_args+=(--dry-run)
      infinity_log_command "$INFINITY_REPO/bin/infinity-deploy" "${deploy_args[@]}"
      ;;
    validate)
      infinity_log_command "$INFINITY_REPO/bin/infinity-validate"
      ;;
    preview)
      if [[ $INFINITY_DRY_RUN == 1 ]]; then
        infinity_log "PLAN preview: validate repository before package writes"
        infinity_log "PLAN preview packages: pacman -Syu --needed --noconfirm $(infinity_preview_packages | paste -sd ' ' -)"
        infinity_log "PLAN preview deploy: infinity-deploy --scope user --target-root $INFINITY_TARGET_ROOT --target-user $INFINITY_TARGET_USER --dry-run"
        "$INFINITY_REPO/bin/infinity-deploy" --scope user --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER" --dry-run
        infinity_log "PLAN preview theme: apply Signal Archive to user config"
        "$INFINITY_REPO/bin/infinity-theme" apply signal-archive --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER" --dry-run
        infinity_log "PLAN preview: no greeter, boot, service enablement, partitioning, or automatic session launch"
        return
      fi
      infinity_preview_preflight
      infinity_log "preview: validating repository before package writes"
      infinity_log_command "$INFINITY_REPO/bin/infinity-validate"
      infinity_log "preview: installing official packages in one pacman transaction"
      infinity_log_command infinity_install_preview_packages
      infinity_log "preview: deploying user-scoped configuration with backups"
      infinity_log_command "$INFINITY_REPO/bin/infinity-deploy" --scope user --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER"
      infinity_log "preview: applying Signal Archive theme"
      infinity_log_command "$INFINITY_REPO/bin/infinity-theme" apply signal-archive --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER"
      infinity_log "preview: if deploy/theme fails after packages install, rerun the same preview command after fixing the reported error; pacman packages may remain installed"
      infinity_preview_success
      ;;
    *) infinity_die "unknown stage '$stage'" ;;
  esac
}

infinity_installer_main() {
  INFINITY_REPO=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
  INFINITY_TARGET_ROOT=/
  INFINITY_TARGET_USER=${SUDO_USER:-${USER:-}}
  INFINITY_DRY_RUN=1
  local confirmed=0
  local selected=()

  while (($#)); do
    case "$1" in
      --help) infinity_usage; return 0 ;;
      --plan|--dry-run) INFINITY_DRY_RUN=1; shift ;;
      --confirm) confirmed=1; INFINITY_DRY_RUN=0; shift ;;
      --target-root) [[ $# -ge 2 ]] || infinity_die "--target-root needs a value"; INFINITY_TARGET_ROOT=$2; shift 2 ;;
      --target-user) [[ $# -ge 2 ]] || infinity_die "--target-user needs a value"; INFINITY_TARGET_USER=$2; shift 2 ;;
      --stage) [[ $# -ge 2 ]] || infinity_die "--stage needs a value"; infinity_has_stage "$2" || infinity_die "invalid stage '$2'"; selected+=("$2"); shift 2 ;;
      *) infinity_die "unknown option '$1'" ;;
    esac
  done

  if [[ $INFINITY_DRY_RUN == 0 && $confirmed != 1 ]]; then
    infinity_die "non-dry-run requires --confirm"
  fi

  if ((${#selected[@]} == 0)); then
    selected=("${INFINITY_STAGES[@]}")
  fi

  if [[ $INFINITY_DRY_RUN == 0 ]]; then
    infinity_validate_apply_selection "${selected[@]}"
  fi

  [[ -d $INFINITY_TARGET_ROOT ]] || infinity_die "target root '$INFINITY_TARGET_ROOT' does not exist"
  [[ $INFINITY_TARGET_USER =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || infinity_die "target user must be a portable Unix account name"

  if [[ $INFINITY_DRY_RUN == 0 ]]; then
    local stage
    for stage in "${selected[@]}"; do
      [[ $stage == preview ]] && infinity_preview_preflight
    done
  fi

  if [[ $INFINITY_DRY_RUN == 1 ]]; then
    INFINITY_LOG=/dev/null
  else
    INFINITY_LOG="$INFINITY_TARGET_ROOT/var/log/infinity-os/install.log"
    PYTHONPATH="$INFINITY_REPO/installation/lib" python3 - "$INFINITY_TARGET_ROOT" "$INFINITY_LOG" <<'PY'
import sys
from pathlib import Path
from safe_fs import init_regular, resolve_root
root = resolve_root(sys.argv[1])
destination = Path(sys.argv[2])
if not destination.is_absolute():
    destination = Path(os.path.abspath(destination))
init_regular(root, destination, 0o644)
PY
  fi

  local stage
  for stage in "${selected[@]}"; do
    infinity_run_stage "$stage"
  done
  infinity_log "DONE"
}
