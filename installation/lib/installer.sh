#!/usr/bin/bash
set -Eeuo pipefail
PATH=/usr/bin:/bin
export PATH

INFINITY_PYTHON=/usr/bin/python3
INFINITY_LOG_RELATIVE=var/log/infinity-os/install.log

INFINITY_STAGES=(preflight repositories packages base hardware wayland desktop-shell applications services boot greeter themes deploy validate preview)
INFINITY_APPLY_STAGES=(preflight packages services greeter themes deploy validate preview)
INFINITY_PREVIEW_ARGV=()
INFINITY_PACKAGES_ARGV=()
INFINITY_PACKAGES_MICROCODE_PACKAGE=
INFINITY_PACKAGES_MICROCODE_REASON=
INFINITY_GREETER_SNAPSHOT_FILES=(
  install.sh
  installation/lib/installer.sh
  installation/lib/safe_fs.py
  installation/stages/greeter.py
  system/services/greetd-tuigreet-recovery.toml
  desktop/greeter/start-greeter
  desktop/greeter/regreet.toml
  desktop/greeter/regreet.css
  desktop/greeter/shell.qml
  desktop/wallpapers/nocturne.svg
  system/services/greetd.toml
)

read -r -d '' INFINITY_GREETER_SNAPSHOT_BOOTSTRAP <<'PY' || true
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ALLOWLIST = (
    "install.sh",
    "installation/lib/installer.sh",
    "installation/lib/safe_fs.py",
    "installation/stages/greeter.py",
    "system/services/greetd-tuigreet-recovery.toml",
    "desktop/greeter/start-greeter",
    "desktop/greeter/regreet.toml",
    "desktop/greeter/regreet.css",
    "desktop/greeter/shell.qml",
    "desktop/wallpapers/nocturne.svg",
    "system/services/greetd.toml",
)
USERNAME = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")


def fail(message):
    raise SystemExit(f"infinity greeter snapshot: {message}")


def parse_manifest(raw):
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as error:
        fail(f"invalid bootstrap manifest JSON: {error}; no target changes were made")
    if not isinstance(data, dict):
        fail("bootstrap manifest must be an object; no target changes were made")
    repo = data.get("repo")
    target_user = data.get("target_user")
    files = data.get("files")
    if not isinstance(repo, str) or not repo.startswith("/"):
        fail("bootstrap manifest repo must be an absolute path; no target changes were made")
    if not isinstance(target_user, str) or not USERNAME.fullmatch(target_user):
        fail("bootstrap manifest target_user is not a portable Unix account name; no target changes were made")
    if not isinstance(files, dict):
        fail("bootstrap manifest files must be an object; no target changes were made")
    if tuple(sorted(files)) != tuple(sorted(ALLOWLIST)):
        fail("bootstrap manifest files do not match the fixed greeter allowlist; rerun the normal installer command")
    for relative, digest in files.items():
        if not isinstance(relative, str) or relative.startswith("/") or "//" in relative or any(part in {"", ".", ".."} for part in relative.split("/")):
            fail(f"unsafe bootstrap relative path {relative!r}; no target changes were made")
        if not isinstance(digest, str) or len(digest) != 64 or any(character not in "0123456789abcdef" for character in digest):
            fail(f"invalid digest for {relative}; no target changes were made")
    return Path(repo), target_user, files


def open_repo(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError as error:
        fail(f"cannot open source repository safely: {error}; no target changes were made")
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) & 0o022:
            fail("source repository must be root-owned and not group/world-writable; no target changes were made")
        return fd
    except BaseException:
        os.close(fd)
        raise


def open_relative(root_fd, relative):
    fd = os.dup(root_fd)
    try:
        parts = relative.split("/")
        for part in parts[:-1]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            metadata = os.fstat(next_fd)
            if metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) & 0o022:
                os.close(next_fd)
                fail(f"greeter snapshot source directory is not trusted: {relative}; no target changes were made")
            os.close(fd)
            fd = next_fd
        file_fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
    except OSError as error:
        os.close(fd)
        fail(f"cannot open greeter snapshot source {relative}: {error}; no target changes were made")
    os.close(fd)
    metadata = os.fstat(file_fd)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_nlink != 1 or stat.S_IMODE(metadata.st_mode) & 0o022:
        os.close(file_fd)
        fail(f"greeter snapshot source {relative} is not a trusted single-linked regular file; no target changes were made")
    return file_fd, metadata


def read_verified(root_fd, relative, expected_digest):
    file_fd, metadata = open_relative(root_fd, relative)
    chunks = []
    digest = hashlib.sha256()
    try:
        while True:
            chunk = os.read(file_fd, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
            digest.update(chunk)
    finally:
        os.close(file_fd)
    data = b"".join(chunks)
    if not data:
        fail(f"greeter snapshot source {relative} is empty; no target changes were made")
    if digest.hexdigest() != expected_digest:
        fail(f"digest mismatch for {relative}; no target changes were made; rerun the normal installer command")
    return data, stat.S_IMODE(metadata.st_mode)


def safe_snapshot_parent():
    for candidate in (Path("/run"), Path("/root")):
        try:
            metadata = candidate.stat()
        except OSError:
            continue
        if stat.S_ISDIR(metadata.st_mode) and metadata.st_uid == 0 and stat.S_IMODE(metadata.st_mode) & 0o022 == 0:
            return candidate
    fail("no safe root-owned snapshot parent is available under /run or /root; no target changes were made")


def write_snapshot_file(snapshot, relative, data, source_mode):
    destination = snapshot.joinpath(*relative.split("/"))
    destination.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, source_mode & 0o755)
    try:
        view = memoryview(data)
        while view:
            written = os.write(fd, view)
            if written == 0:
                fail(f"short write while creating trusted snapshot file {relative}; no target changes were made")
            view = view[written:]
        os.fsync(fd)
    finally:
        os.close(fd)
    os.chmod(destination, source_mode & 0o755)


def validate_written_snapshot(snapshot):
    root_metadata = snapshot.stat(follow_symlinks=False)
    if root_metadata.st_uid != 0 or stat.S_IMODE(root_metadata.st_mode) != 0o700:
        fail("trusted snapshot root is not root-owned 0700; no target changes were made")
    for relative in ALLOWLIST:
        path = snapshot.joinpath(*relative.split("/"))
        metadata = path.stat(follow_symlinks=False)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_nlink != 1 or stat.S_IMODE(metadata.st_mode) & 0o022:
            fail(f"trusted snapshot file {relative} failed ownership or mode validation; no target changes were made")


def main():
    if len(sys.argv) != 2:
        fail("expected one JSON bootstrap manifest argument; no target changes were made")
    repo, target_user, files = parse_manifest(sys.argv[1])
    root_fd = open_repo(repo)
    snapshot = None
    try:
        payloads = []
        for relative in ALLOWLIST:
            data, mode = read_verified(root_fd, relative, files[relative])
            payloads.append((relative, data, mode))
        snapshot = Path(tempfile.mkdtemp(prefix="infinity-greeter-", dir=safe_snapshot_parent()))
        os.chmod(snapshot, 0o700)
        for relative, data, mode in payloads:
            write_snapshot_file(snapshot, relative, data, mode)
        validate_written_snapshot(snapshot)
        env = {"PATH": "/usr/bin:/bin", "INFINITY_GREETER_TRUSTED_SNAPSHOT": str(snapshot)}
        command = ["/usr/bin/bash", str(snapshot / "install.sh"), "--confirm", "--target-root", "/", "--target-user", target_user, "--stage", "greeter"]
        return subprocess.run(command, env=env, check=False).returncode
    finally:
        os.close(root_fd)
        if snapshot is not None:
            shutil.rmtree(snapshot)


raise SystemExit(main())
PY

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
  preflight,packages,services,greeter,themes,deploy,validate,preview

Confirmed packages/services/greeter/preview runs request sudo automatically when needed.

No disk partitioning is performed.
USAGE
}

infinity_die() {
  printf 'infinity install: %s\n' "$1" >&2
  exit 1
}

infinity_effective_uid() {
  printf '%s\n' "${EUID:-$(id -u)}"
}

infinity_exec_sudo() {
  [[ -x /usr/bin/sudo ]] || infinity_die "this stage needs root privileges, but /usr/bin/sudo is unavailable; install sudo or run the reviewed command as root"
  exec /usr/bin/sudo -- "$@"
}

infinity_exec_as_target_user() {
  local user=$1
  shift
  [[ -x /usr/bin/sudo ]] || infinity_die "repository validation must run as target user '$user', but /usr/bin/sudo is unavailable"
  /usr/bin/sudo -u "$user" -- "$@"
}

infinity_greeter_snapshot_manifest_json() {
  "$INFINITY_PYTHON" - "$INFINITY_REPO" "$INFINITY_TARGET_USER" "${INFINITY_GREETER_SNAPSHOT_FILES[@]}" <<'PY'
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

repo = Path(sys.argv[1]).resolve(strict=True)
target_user = sys.argv[2]
relative_paths = sys.argv[3:]
digests = {}
root_fd = os.open(repo, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    for relative in relative_paths:
        if relative.startswith("/") or "//" in relative or any(part in {"", ".", ".."} for part in relative.split("/")):
            raise SystemExit(f"unsafe greeter snapshot source path {relative!r}")
        fd = os.dup(root_fd)
        try:
            parts = relative.split("/")
            for part in parts[:-1]:
                next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
                os.close(fd)
                fd = next_fd
            file_fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        finally:
            os.close(fd)
        try:
            metadata = os.fstat(file_fd)
            if not stat.S_ISREG(metadata.st_mode):
                raise SystemExit(f"greeter snapshot source is not a regular file: {relative}")
            digest = hashlib.sha256()
            saw_bytes = False
            while True:
                chunk = os.read(file_fd, 1024 * 1024)
                if not chunk:
                    break
                saw_bytes = True
                digest.update(chunk)
            if not saw_bytes:
                raise SystemExit(f"greeter snapshot source is empty: {relative}")
            digests[relative] = digest.hexdigest()
        finally:
            os.close(file_fd)
finally:
    os.close(root_fd)
print(json.dumps({"repo": str(repo), "target_user": target_user, "files": digests}, sort_keys=True, separators=(",", ":")))
PY
}

infinity_validate_greeter_source_repository() {
  "$INFINITY_PYTHON" - "$INFINITY_REPO" "${INFINITY_GREETER_SNAPSHOT_FILES[@]}" <<'PY'
import os
import stat
import sys
from pathlib import Path

repo = Path(sys.argv[1])
if not repo.is_absolute():
    raise SystemExit("greeter source repository path must be absolute; no privileged work was started")
current = Path("/")
for part in repo.parts[1:]:
    current /= part
    metadata = os.stat(current, follow_symlinks=False)
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) & 0o022:
        raise SystemExit(
            f"greeter source path must be root-owned and not group/world-writable: {current}; "
            "copy the repository to a reviewed root-owned location such as /opt/infinity-os and rerun"
        )
root_fd = os.open(repo, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    for relative in sys.argv[2:]:
        fd = os.dup(root_fd)
        try:
            parts = relative.split("/")
            for part in parts[:-1]:
                next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
                metadata = os.fstat(next_fd)
                if metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) & 0o022:
                    raise SystemExit(f"untrusted greeter source directory for {relative}; no privileged work was started")
                os.close(fd)
                fd = next_fd
            file_fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        finally:
            os.close(fd)
        try:
            metadata = os.fstat(file_fd)
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_nlink != 1 or stat.S_IMODE(metadata.st_mode) & 0o022:
                raise SystemExit(f"untrusted greeter source file {relative}; no privileged work was started")
        finally:
            os.close(file_fd)
finally:
    os.close(root_fd)
PY
}

infinity_exec_greeter_snapshot_sudo() {
  [[ -x /usr/bin/sudo ]] || infinity_die "greeter apply needs root privileges, but /usr/bin/sudo is unavailable; install sudo or run the reviewed command as root through the trusted snapshot path"
  local manifest_json
  infinity_validate_greeter_source_repository
  manifest_json=$(infinity_greeter_snapshot_manifest_json) || infinity_die "cannot build greeter snapshot manifest; no privileged work was started"
  printf 'infinity install: greeter requires root privileges; requesting sudo authentication for a verified root-owned snapshot\n' >&2
  infinity_exec_sudo "$INFINITY_PYTHON" -c "$INFINITY_GREETER_SNAPSHOT_BOOTSTRAP" "$manifest_json"
}

infinity_elevate_apply_if_required() {
  local stage needs_root=0
  for stage in "$@"; do
    if [[ $stage == preview || $stage == packages || $stage == services || $stage == greeter ]]; then
      needs_root=1
      break
    fi
  done
  [[ $needs_root == 1 ]] || return 0
  [[ $(infinity_effective_uid) -ne 0 ]] || return 0

  if [[ $# -eq 1 && $1 == greeter ]]; then
    infinity_exec_greeter_snapshot_sudo
    return $?
  fi

  local elevated_args=(
    "$INFINITY_REPO/install.sh"
    --confirm
    --target-root "$INFINITY_TARGET_ROOT"
    --target-user "$INFINITY_TARGET_USER"
  )
  for stage in "$@"; do
    elevated_args+=(--stage "$stage")
  done
  printf 'infinity install: stage requires root privileges; requesting sudo authentication\n' >&2
  infinity_exec_sudo "${elevated_args[@]}"
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
  local unsupported=() stage has_preview=0 has_packages=0 has_services=0 has_greeter=0 count=0
  for stage in "$@"; do
    count=$((count + 1))
    [[ $stage == preview ]] && has_preview=1
    [[ $stage == packages ]] && has_packages=1
    [[ $stage == services ]] && has_services=1
    [[ $stage == greeter ]] && has_greeter=1
    infinity_has_apply_stage "$stage" || unsupported+=("$stage")
  done
  if ((${#unsupported[@]})); then
    infinity_die "selected stages are plan-only: ${unsupported[*]}; use --plan or select only preflight,packages,services,greeter,themes,deploy,validate,preview"
  fi
  if [[ $has_preview == 1 && $count -ne 1 ]]; then
    infinity_die "preview apply must be selected by itself; run only --stage preview so deployment stays user-scoped"
  fi
  if [[ $has_packages == 1 && $count -ne 1 ]]; then
    infinity_die "packages apply must be selected by itself; run only --stage packages so package installation cannot mix with deployment, services, boot, greeter, or theme actions"
  fi
  if [[ $has_services == 1 && $count -ne 1 ]]; then
    infinity_die "services apply must be selected by itself; run only --stage services so offline enablement cannot mix with package, deployment, boot, greeter, or theme actions"
  fi
  if [[ $has_greeter == 1 && $count -ne 1 ]]; then
    infinity_die "greeter apply must be selected by itself; run only --stage greeter so display-manager selection cannot mix with package, service, boot, deployment, or theme actions"
  fi
}

infinity_log_append() {
  [[ $INFINITY_DRY_RUN == 1 ]] && return 0
  PYTHONPATH="$INFINITY_REPO/installation/lib" "$INFINITY_PYTHON" - "$INFINITY_TARGET_ROOT" "$INFINITY_LOG_RELATIVE" "$1" <<'PY'
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
  [[ -x /usr/bin/pacman ]] || infinity_die "packages apply requires executable /usr/bin/pacman; run this on an already bootable Arch system"
}

infinity_services_preflight() {
  local resolved
  resolved=$(infinity_resolved_root "$INFINITY_TARGET_ROOT") || infinity_die "cannot resolve target root '$INFINITY_TARGET_ROOT'"
  [[ $resolved != / ]] || infinity_die "services apply requires an offline target and refuses the live root /"
  if [[ -e $resolved/run/systemd/system || -L $resolved/run/systemd/system || -e $resolved/run/systemd/private || -L $resolved/run/systemd/private ]]; then
    infinity_die "services target '$resolved' appears active because it contains systemd runtime state; stop or unmount that target before enabling services"
  fi
  INFINITY_TARGET_ROOT=$resolved
}

infinity_validate_greeter_trusted_snapshot() {
  local marker=${INFINITY_GREETER_TRUSTED_SNAPSHOT:-}
  [[ -n $marker ]] || infinity_die "greeter apply must enter root through the verified trusted snapshot; rerun as a normal user with: ./install.sh --confirm --stage greeter"
  [[ $marker == "$INFINITY_REPO" ]] || infinity_die "greeter trusted snapshot marker does not match the running installer; no target changes were made"
  "$INFINITY_PYTHON" - "$INFINITY_REPO" "${INFINITY_GREETER_SNAPSHOT_FILES[@]}" <<'PY'
import os
import stat
import sys
from pathlib import Path

repo = Path(sys.argv[1]).resolve(strict=True)
relative_paths = sys.argv[2:]
root_metadata = repo.stat(follow_symlinks=False)
if not stat.S_ISDIR(root_metadata.st_mode) or root_metadata.st_uid != 0 or stat.S_IMODE(root_metadata.st_mode) != 0o700:
    raise SystemExit("trusted greeter snapshot root must be root-owned mode 0700; no target changes were made")
root_fd = os.open(repo, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    for relative in relative_paths:
        if relative.startswith("/") or "//" in relative or any(part in {"", ".", ".."} for part in relative.split("/")):
            raise SystemExit(f"unsafe trusted greeter snapshot path {relative!r}; no target changes were made")
        fd = os.dup(root_fd)
        try:
            parts = relative.split("/")
            for part in parts[:-1]:
                next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
                metadata = os.fstat(next_fd)
                if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) & 0o022:
                    raise SystemExit(f"trusted greeter snapshot directory for {relative} failed ownership or mode validation; no target changes were made")
                os.close(fd)
                fd = next_fd
            file_fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        finally:
            os.close(fd)
        try:
            metadata = os.fstat(file_fd)
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_nlink != 1 or stat.S_IMODE(metadata.st_mode) & 0o022:
                raise SystemExit(f"trusted greeter snapshot file {relative} failed regularity, ownership, link count, or mode validation; no target changes were made")
        finally:
            os.close(file_fd)
finally:
    os.close(root_fd)
PY
}

infinity_greeter_preflight() {
  local resolved
  resolved=$(infinity_resolved_root "$INFINITY_TARGET_ROOT") || infinity_die "cannot resolve target root '$INFINITY_TARGET_ROOT'"
  [[ $resolved == / ]] || infinity_die "greeter apply only supports --target-root / on the running Arch system; got '$resolved'. Use --plan for other roots."
  if [[ $(infinity_effective_uid) -eq 0 ]]; then
    infinity_validate_greeter_trusted_snapshot
  fi
  INFINITY_TARGET_ROOT=$resolved
}

infinity_prewrite_services_validation() {
  PYTHONPATH="$INFINITY_REPO/installation/lib" "$INFINITY_PYTHON" "$INFINITY_REPO/installation/stages/services.py" validate \
    --target-root "$INFINITY_TARGET_ROOT" \
    --manifest "$INFINITY_REPO/system/services/enabled-system-units.tsv"
}

infinity_prewrite_greeter_validation() {
  "$INFINITY_PYTHON" "$INFINITY_REPO/installation/stages/greeter.py" validate \
    --target-root "$INFINITY_TARGET_ROOT"
}

infinity_prewrite_repository_validation() {
  if [[ $(infinity_effective_uid) -eq 0 && $INFINITY_TARGET_USER != root ]]; then
    infinity_exec_as_target_user "$INFINITY_TARGET_USER" "$INFINITY_REPO/bin/infinity-validate"
  else
    "$INFINITY_REPO/bin/infinity-validate"
  fi
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
        infinity_log "packages: pacman failed; package state may have changed, no package removal was attempted. Resolve pacman, then rerun: ./install.sh --confirm --stage packages"
        return 1
      fi
      infinity_log "packages: complete; graphics, AUR, services, boot, greeter, deploy, and theme actions were not run"
      ;;
    services)
      local services_action=apply
      [[ $INFINITY_DRY_RUN == 1 ]] && services_action=plan
      infinity_log_command "$INFINITY_PYTHON" "$INFINITY_REPO/installation/stages/services.py" "$services_action" \
        --target-root "$INFINITY_TARGET_ROOT" \
        --manifest "$INFINITY_REPO/system/services/enabled-system-units.tsv"
      ;;
    boot)
      infinity_log "PLAN install systemd-boot/Plymouth templates from system/boot and system/plymouth after UUID review"
      ;;
    greeter)
      local greeter_action=apply
      [[ $INFINITY_DRY_RUN == 1 ]] && greeter_action=plan
      infinity_log_command "$INFINITY_PYTHON" "$INFINITY_REPO/installation/stages/greeter.py" "$greeter_action" \
        --target-root "$INFINITY_TARGET_ROOT"
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
        infinity_log "preview: pacman failed; package state may have changed, no package removal was attempted. Resolve pacman, then rerun: ./install.sh --confirm --stage preview --target-user $INFINITY_TARGET_USER"
        return 1
      fi
      infinity_log "preview: deploying user-scoped configuration with backups"
      infinity_log_command infinity_exec_as_target_user "$INFINITY_TARGET_USER" "$INFINITY_REPO/bin/infinity-deploy" --scope user --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER"
      infinity_log "preview: applying Signal Archive theme"
      infinity_log_command infinity_exec_as_target_user "$INFINITY_TARGET_USER" "$INFINITY_REPO/bin/infinity-theme" apply signal-archive --target-root "$INFINITY_TARGET_ROOT" --target-user "$INFINITY_TARGET_USER"
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
      [[ $stage == packages ]] && infinity_packages_preflight
      [[ $stage == services ]] && infinity_services_preflight
      [[ $stage == greeter ]] && infinity_greeter_preflight
    done
    infinity_elevate_apply_if_required "${selected[@]}" || return $?
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
      elif [[ $stage == services ]]; then
        infinity_prewrite_services_validation
      elif [[ $stage == greeter ]]; then
        infinity_prewrite_greeter_validation
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
