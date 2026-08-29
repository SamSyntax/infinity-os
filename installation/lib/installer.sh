#!/usr/bin/bash
set -Eeuo pipefail
PATH=/usr/bin:/bin
export PATH

INFINITY_PYTHON=/usr/bin/python3
INFINITY_LOG_RELATIVE=var/log/infinity-os/install.log

INFINITY_STAGES=(preflight repositories packages base hardware wayland desktop-shell applications services boot greeter themes deploy validate preview)
INFINITY_APPLY_STAGES=(preflight packages themes deploy validate preview)
INFINITY_PREVIEW_ARGV=()
INFINITY_PACKAGES_ARGV=()
INFINITY_PACKAGES_MICROCODE_PACKAGE=
INFINITY_PACKAGES_MICROCODE_REASON=

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
  preflight,repositories,packages,base,hardware,wayland,desktop-shell,applications,services,boot,greeter,themes,deploy,validate,preview

Apply-capable stages:
  preflight,packages,themes,deploy,validate,preview

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
  local unsupported=() stage has_preview=0 has_packages=0 count=0
  for stage in "$@"; do
    count=$((count + 1))
    [[ $stage == preview ]] && has_preview=1
    [[ $stage == packages ]] && has_packages=1
    infinity_has_apply_stage "$stage" || unsupported+=("$stage")
  done
  if ((${#unsupported[@]})); then
    infinity_die "selected stages are plan-only: ${unsupported[*]}; use --plan or select only preflight,packages,themes,deploy,validate,preview"
  fi
  if [[ $has_preview == 1 && $count -ne 1 ]]; then
    infinity_die "preview apply must be selected by itself; run only --stage preview so deployment stays user-scoped"
  fi
  if [[ $has_packages == 1 && $count -ne 1 ]]; then
    infinity_die "packages apply must be selected by itself; run only --stage packages so package installation cannot mix with deployment, services, boot, greeter, or theme actions"
  fi
}

infinity_log_append() {
  [[ $INFINITY_DRY_RUN == 1 ]] && return 0
  # PYTHONPATH="$INFINITY_REPO/installation/lib" "$INFINITY_PYTHON" - "$INFINITY_TARGET_ROOT" "$INFINITY_LOG_RELATIVE" "$1" <<'PY'
  local runner=()
  if [[ ! -w "$INFINITY_TARGET_ROOT/var/log" && ${EUID:-$(id -u)} -ne 0]]; then
    runner=(sudo)
  fi
  "${runner[@]}" PYTHONPATH="$INFINITY_REPO/installation/lib" "$INFINITY_PYTHON" - "$INFINITY_TARGET_ROOT" "$INFINITY_LOG_RELATIVE" "$1" <<'PY'

import sys
from safe_fs import append_regular, resolve_root, validate_relative
root = resolve_root(sys.argv[1])
destination = root / validate_relative(sys.argv[2])
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
  "$INFINITY_PYTHON" - "$file" <<'PY'
import os
import sys
for line in open(sys.argv[1], encoding='utf-8'):
    item=line.split('#',1)[0].strip()
    if item:
        print(item)
PY
}

infinity_preview_packages() {
  local file="${1:-$INFINITY_REPO/installation/preview-packages.official.txt}"
  "$INFINITY_PYTHON" - "$file" <<'PY'
import re
import sys
pattern = re.compile(r"^[a-z0-9][a-z0-9@._+-]*$")
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
  local argv=() output
  if ((${#INFINITY_PREVIEW_ARGV[@]})); then
    argv=("${INFINITY_PREVIEW_ARGV[@]}")
  else
    output=$(infinity_preview_pacman_argv "$@") || return
    mapfile -t argv <<<"$output"
  fi
  ((${#argv[@]})) || infinity_die "preview pacman command is empty"
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    sudo "${argv[@]}"
  else
    "${argv[@]}"
  fi

}

infinity_preview_pacman_argv() {
  local output packages=()
  output=$(infinity_preview_packages "$@") || return
  mapfile -t packages <<<"$output"
  ((${#packages[@]})) || infinity_die "preview package manifest is empty"
  printf '%s\n' /usr/bin/pacman -Syu --needed --noconfirm -- "${packages[@]}"
}

infinity_compute_preview_argv() {
  local output
  output=$(infinity_preview_pacman_argv) || return
  mapfile -t INFINITY_PREVIEW_ARGV <<<"$output"
  ((${#INFINITY_PREVIEW_ARGV[@]})) || infinity_die "preview pacman command is empty"
}

infinity_compute_packages_argv() {
  local lines=() line output
  output=$(PYTHONPATH="$INFINITY_REPO/installation/lib" "$INFINITY_PYTHON" - "$INFINITY_REPO" <<'PY'
import sys
from pathlib import Path
from package_selection import PackageSelectionError, pacman_argv, production_microcode_decision, select_repository_packages

try:
    repo = Path(sys.argv[1])
    microcode = production_microcode_decision()
    packages = select_repository_packages(repo, microcode)
    print(f"MICROCODE\t{microcode.package or '-'}\t{microcode.reason}")
    for item in pacman_argv(packages):
        print(item)
except (OSError, PackageSelectionError) as error:
    raise SystemExit(str(error))
PY
  ) || return
  mapfile -t lines <<<"$output"
  ((${#lines[@]} >= 6)) || infinity_die "packages pacman command is empty"
  line=${lines[0]}
  [[ $line == MICROCODE$'\t'* ]] || infinity_die "packages microcode decision was not reported"
  IFS=$'\t' read -r _ INFINITY_PACKAGES_MICROCODE_PACKAGE INFINITY_PACKAGES_MICROCODE_REASON <<<"$line"
  INFINITY_PACKAGES_ARGV=("${lines[@]:1}")
  [[ ${INFINITY_PACKAGES_ARGV[0]} == /usr/bin/pacman ]] || infinity_die "packages pacman command must use /usr/bin/pacman"
}

infinity_packages_pacman_argv() {
  if ((${#INFINITY_PACKAGES_ARGV[@]} == 0)); then
    infinity_compute_packages_argv
  fi
  printf '%s\n' "${INFINITY_PACKAGES_ARGV[@]}"
}

infinity_install_packages() {
  local argv=()
  if ((${#INFINITY_PACKAGES_ARGV[@]})); then
    argv=("${INFINITY_PACKAGES_ARGV[@]}")
  else
    mapfile -t argv < <(infinity_packages_pacman_argv)
  fi
  ((${#argv[@]})) || infinity_die "packages pacman command is empty"
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    sudo "${argv[@]}"
  else
    "${argv[@]}"
  fi
}

infinity_resolved_root() {
  "$INFINITY_PYTHON" - "$1" <<'PY'
import sys
from pathlib import Path
print(Path(sys.argv[1]).resolve(strict=True))
PY
}

infinity_preview_preflight() {
  local resolved uid home
  resolved=$(infinity_resolved_root "$INFINITY_TARGET_ROOT") || infinity_die "cannot resolve target root '$INFINITY_TARGET_ROOT'"
  [[ $resolved == / ]] || infinity_die "preview apply only supports --target-root / on the running VM; got '$resolved'. Use --plan for other roots."
  # [[ ${EUID:-$(id -u)} == 0 ]] || infinity_die "preview apply must run as root with sudo so pacman and user deployment can write to the VM"
  [[ -x /usr/bin/pacman ]] || infinity_die "preview apply requires executable /usr/bin/pacman; run this on an already bootable Arch VM, not this development host or a non-Arch environment"
  getent passwd "$INFINITY_TARGET_USER" >/dev/null || infinity_die "target user '$INFINITY_TARGET_USER' does not exist on this VM"
  uid=$(getent passwd "$INFINITY_TARGET_USER" | cut -d: -f3)
  home=$(getent passwd "$INFINITY_TARGET_USER" | cut -d: -f6)
  [[ $uid =~ ^[0-9]+$ && $uid -ne 0 ]] || infinity_die "target user '$INFINITY_TARGET_USER' must be a non-root account"
  [[ $home == "/home/$INFINITY_TARGET_USER" ]] || infinity_die "target user '$INFINITY_TARGET_USER' home must be exactly /home/$INFINITY_TARGET_USER, got '$home'"
}

infinity_packages_preflight() {
  local resolved
  resolved=$(infinity_resolved_root "$INFINITY_TARGET_ROOT") || infinity_die "cannot resolve target root '$INFINITY_TARGET_ROOT'"
  [[ $resolved == / ]] || infinity_die "packages apply only supports --target-root / on the running Arch system; got '$resolved'. Use --plan for other roots."
  # [[ ${EUID:-$(id -u)} == 0 ]] || infinity_die "packages apply must run as root with sudo so pacman can write to the live system"
  [[ -x /usr/bin/pacman ]] || infinity_die "packages apply requires executable /usr/bin/pacman; run this on an already bootable Arch system"
}

infinity_prewrite_repository_validation() {
  "$INFINITY_REPO/bin/infinity-validate"
}

infinity_prewrite_packages_validation() {
  local package
  ((${#INFINITY_PACKAGES_ARGV[@]} >= 7)) || infinity_die "packages pacman command is incomplete"
  [[ ${INFINITY_PACKAGES_ARGV[0]} == /usr/bin/pacman ]] || infinity_die "packages pacman command must use /usr/bin/pacman"
  [[ ${INFINITY_PACKAGES_ARGV[1]} == -Syu ]] || infinity_die "packages pacman command must perform a full system upgrade"
  [[ ${INFINITY_PACKAGES_ARGV[2]} == --needed ]] || infinity_die "packages pacman command must use --needed"
  [[ ${INFINITY_PACKAGES_ARGV[3]} == --noconfirm ]] || infinity_die "packages pacman command must use --noconfirm"
  [[ ${INFINITY_PACKAGES_ARGV[4]} == -- ]] || infinity_die "packages pacman options must end before package names"
  for package in "${INFINITY_PACKAGES_ARGV[@]:5}"; do
    [[ $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || infinity_die "invalid package token in packages pacman command: '$package'"
  done
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
    packages)
      if [[ $INFINITY_DRY_RUN == 1 ]]; then
        infinity_compute_packages_argv
        infinity_log "PLAN packages: package manifests and fixed pacman argv are validated before package writes and before log creation"
        infinity_log "PLAN packages: microcode ${INFINITY_PACKAGES_MICROCODE_PACKAGE} (${INFINITY_PACKAGES_MICROCODE_REASON})"
        infinity_log "PLAN packages: includes official groups base,hardware,wayland,desktop-shell,applications in that order"
        infinity_log "PLAN packages: graphics and AUR manifests are deferred; no services, boot, greeter, deploy, or theme actions"
        infinity_log "PLAN packages command: ${INFINITY_PACKAGES_ARGV[*]}"
        return
      fi
      infinity_log "packages: installing official workstation package groups in one pacman transaction"
      if ! infinity_log_command infinity_install_packages; then
        infinity_log "packages: pacman failed; package state may have changed, no package removal was attempted. Resolve pacman, then rerun: sudo ./install.sh --confirm --stage packages"
        return 1
      fi
      infinity_log "packages: complete; graphics, AUR, services, boot, greeter, deploy, and theme actions were not run"
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
        infinity_compute_preview_argv
        infinity_log "PLAN preview packages: ${INFINITY_PREVIEW_ARGV[*]}"
        infinity_log "PLAN preview deploy: infinity-deploy --scope user --target-root $INFINITY_TARGET_ROOT --target-user $INFINITY_TARGET_USER --dry-run"
        "$INFINITY_REPO/bin/infinity-deploy" --scope user --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER" --dry-run
        infinity_log "PLAN preview theme: apply Signal Archive to user config"
        "$INFINITY_REPO/bin/infinity-theme" apply signal-archive --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER" --dry-run
        infinity_log "PLAN preview: no greeter, boot, service enablement, partitioning, or automatic session launch"
        return
      fi
      infinity_preview_preflight
      infinity_log "preview: installing official packages in one pacman transaction"
      if ! infinity_log_command infinity_install_preview_packages; then
        infinity_log "preview: pacman failed; package state may have changed, no package removal was attempted. Resolve pacman, then rerun: sudo ./install.sh --confirm --stage preview --target-user $INFINITY_TARGET_USER"
        return 1
      fi
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
  INFINITY_TARGET_USER=${USER:-${id -un}}
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
      [[ $stage == packages ]] && infinity_packages_preflight
    done
  fi

  if [[ $INFINITY_DRY_RUN == 0 ]]; then
    local needs_prewrite_validation=0 stage
    for stage in "${selected[@]}"; do
      if [[ $stage == preview ]]; then
        needs_prewrite_validation=1
        infinity_compute_preview_argv
      elif [[ $stage == packages ]]; then
        infinity_compute_packages_argv
        infinity_prewrite_packages_validation
      fi
    done
    if [[ $needs_prewrite_validation == 1 ]]; then
      infinity_prewrite_repository_validation
    fi
  fi

  if [[ $INFINITY_DRY_RUN == 1 ]]; then
    INFINITY_LOG=/dev/null
  else
    INFINITY_LOG=$INFINITY_LOG_RELATIVE
    PYTHONPATH="$INFINITY_REPO/installation/lib" "$INFINITY_PYTHON" - "$INFINITY_TARGET_ROOT" "$INFINITY_LOG_RELATIVE" <<'PY'
import sys
from safe_fs import init_regular, resolve_root, validate_relative
root = resolve_root(sys.argv[1])
destination = root / validate_relative(sys.argv[2])
init_regular(root, destination, 0o644)
PY
  fi

  local stage
  for stage in "${selected[@]}"; do
    infinity_run_stage "$stage"
  done
  infinity_log "DONE"
}
