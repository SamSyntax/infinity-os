#!/usr/bin/env bash
set -Eeuo pipefail

INFINITY_STAGES=(preflight repositories base hardware wayland desktop-shell applications services boot greeter themes deploy validate)

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
  preflight,repositories,base,hardware,wayland,desktop-shell,applications,services,boot,greeter,themes,deploy,validate

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

infinity_log() {
  printf '%s\n' "$1" | tee -a "$INFINITY_LOG"
}

infinity_manifest_packages() {
  local group=$1
  local file="$INFINITY_REPO/system/packages/$group.official.txt"
  [[ -f $file ]] || return 0
  python3 - "$file" <<'PY'
import sys
for line in open(sys.argv[1], encoding='utf-8'):
    item=line.split('#',1)[0].strip()
    if item:
        print(item)
PY
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
      "$INFINITY_REPO/bin/infinity-theme" apply nocturne --dry-run --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER" | tee -a "$INFINITY_LOG"
      ;;
    deploy)
      local deploy_args=(--target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER")
      [[ $INFINITY_DRY_RUN == 1 ]] && deploy_args+=(--dry-run)
      "$INFINITY_REPO/bin/infinity-deploy" "${deploy_args[@]}" | tee -a "$INFINITY_LOG"
      ;;
    validate)
      "$INFINITY_REPO/bin/infinity-validate" | tee -a "$INFINITY_LOG"
      ;;
    *) infinity_die "unknown stage '$stage'" ;;
  esac
}

infinity_installer_main() {
  INFINITY_REPO=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
  INFINITY_TARGET_ROOT=/
  INFINITY_TARGET_USER=${USER:-}
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

  if [[ $INFINITY_DRY_RUN == 1 ]]; then
    INFINITY_LOG=/dev/null
  else
    install -d -m 0755 "$INFINITY_TARGET_ROOT/var/log/infinity-os"
    INFINITY_LOG="$INFINITY_TARGET_ROOT/var/log/infinity-os/install.log"
  fi
  : > "$INFINITY_LOG"

  local stage
  for stage in "${selected[@]}"; do
    infinity_run_stage "$stage"
  done
  infinity_log "DONE"
}
