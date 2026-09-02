#!/usr/bin/python3
import argparse
import configparser
import errno
import fcntl
import os
import pwd
import stat
import sys
import tomllib
from collections.abc import Callable
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path, PurePosixPath


LIB = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB))

from safe_fs import atomic_write, ensure_symlink, read_existing_regular, remove_regular, resolve_root, validate_symlink


REPO = Path(__file__).resolve().parents[2]
DISPLAY_MANAGER = "/etc/systemd/system/display-manager.service"
GREETD_UNIT = "/usr/lib/systemd/system/greetd.service"
BACKUP_DIRECTORY = "/var/lib/infinity-os/backups/greeter"
REQUIRED_PACKAGES = (
    "greetd",
    "greetd-regreet",
    "greetd-tuigreet",
    "cage",
    "quickshell",
    "hyprland",
)
REQUIRED_EXECUTABLES = (
    "/usr/bin/cage",
    "/usr/bin/regreet",
    "/usr/bin/tuigreet",
    "/usr/bin/quickshell",
    "/usr/bin/Hyprland",
)
HYPRLAND_SESSION = "/usr/share/wayland-sessions/hyprland.desktop"


class GreeterStageError(ValueError):
    pass


@dataclass(frozen=True)
class ManifestEntry:
    source: Path
    target: str
    mode: int


@dataclass(frozen=True)
class GreeterResult:
    target: Path
    status: str
    backup: Path | None = None


@dataclass(frozen=True)
class PreflightChecks:
    package_validator: Callable[[Path], tuple[str, ...]] | None = None
    account_validator: Callable[[Path], bool] | None = None


MANIFEST = (
    ManifestEntry(REPO / "system/services/greetd-tuigreet-recovery.toml", "/etc/greetd/config-tuigreet-recovery.toml", 0o644),
    ManifestEntry(REPO / "desktop/greeter/start-greeter", "/usr/lib/infinity-os/start-greeter", 0o755),
    ManifestEntry(REPO / "desktop/greeter/regreet.toml", "/etc/greetd/regreet.toml", 0o644),
    ManifestEntry(REPO / "desktop/greeter/regreet.css", "/etc/greetd/regreet.css", 0o644),
    ManifestEntry(REPO / "desktop/greeter/shell.qml", "/usr/share/infinity-os/greeter/shell.qml", 0o644),
    ManifestEntry(REPO / "desktop/wallpapers/nocturne.svg", "/usr/share/infinity-os/wallpapers/nocturne.svg", 0o644),
    ManifestEntry(REPO / "system/services/greetd.toml", "/etc/greetd/config.toml", 0o644),
)
ALLOWLIST = frozenset(entry.target for entry in MANIFEST) | frozenset({DISPLAY_MANAGER})


def _target(root: Path, absolute_path: str) -> Path:
    pure = PurePosixPath(absolute_path)
    if not pure.is_absolute() or any(part in {"", ".", ".."} for part in pure.parts):
        raise GreeterStageError(f"invalid greeter target path {absolute_path!r}; no target changes were made; fix the fixed manifest")
    return root.joinpath(*pure.parts[1:])


def _read_target_regular(root: Path, destination: Path) -> tuple[bytes, int] | None:
    relative = destination.relative_to(root)
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in relative.parts[:-1]:
            try:
                next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            except FileNotFoundError:
                return None
            os.close(fd)
            fd = next_fd
        try:
            file_fd = os.open(relative.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        except FileNotFoundError:
            return None
        except OSError as error:
            if error.errno == errno.ELOOP:
                raise GreeterStageError(
                    f"refusing symlinked greeter destination {destination}; no target changes were made; move it aside and rerun"
                ) from error
            raise
        try:
            metadata = os.fstat(file_fd)
            if not stat.S_ISREG(metadata.st_mode):
                raise GreeterStageError(
                    f"refusing non-regular greeter destination {destination}; no target changes were made; move it aside and rerun"
                )
            chunks = []
            while True:
                chunk = os.read(file_fd, 1024 * 1024)
                if not chunk:
                    return b"".join(chunks), stat.S_IMODE(metadata.st_mode)
                chunks.append(chunk)
        finally:
            os.close(file_fd)
    finally:
        os.close(fd)


def _require_safe_target_ancestors(root: Path, destination: Path) -> None:
    relative = destination.relative_to(root)
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in relative.parts[:-1]:
            try:
                metadata = os.stat(part, dir_fd=fd, follow_symlinks=False)
            except FileNotFoundError:
                return
            if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
                raise GreeterStageError(
                    f"unsafe greeter destination parent for {destination}; no target changes were made; replace that path with a real directory"
                )
            if root == Path("/") and (metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) & 0o022):
                raise GreeterStageError(
                    f"untrusted greeter destination parent for {destination}; no target changes were made; restore root ownership and remove group/world write access"
                )
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
    finally:
        os.close(fd)


def _remove_symlink(root: Path, destination: Path) -> None:
    relative = destination.relative_to(root)
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in relative.parts[:-1]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        metadata = os.stat(relative.name, dir_fd=fd, follow_symlinks=False)
        if not stat.S_ISLNK(metadata.st_mode):
            raise GreeterStageError(f"rollback refused to remove non-symlink {destination}; inspect the target manually")
        os.unlink(relative.name, dir_fd=fd)
        os.fsync(fd)
    finally:
        os.close(fd)


def _source_bytes(entry: ManifestEntry) -> bytes:
    try:
        resolved = entry.source.resolve(strict=True)
    except OSError as error:
        raise GreeterStageError(
            f"missing greeter source {entry.source}; no target changes were made; restore the repository file and rerun"
        ) from error
    if not resolved.is_relative_to(REPO):
        raise GreeterStageError(
            f"greeter source escapes the repository: {entry.source}; no target changes were made; fix the fixed manifest"
        )
    metadata = resolved.stat()
    if not stat.S_ISREG(metadata.st_mode):
        raise GreeterStageError(
            f"greeter source is not a regular file: {resolved}; no target changes were made; restore the repository file"
        )
    try:
        data = resolved.read_bytes()
    except OSError as error:
        raise GreeterStageError(
            f"cannot read greeter source {resolved}: {error}; no target changes were made; fix repository permissions and rerun"
        ) from error
    if not data:
        raise GreeterStageError(
            f"greeter source is empty: {resolved}; no target changes were made; restore expected content and rerun"
        )
    _validate_source_semantics(entry, data)
    return data


def _validate_source_semantics(entry: ManifestEntry, data: bytes) -> None:
    if entry.target in {"/etc/greetd/config-tuigreet-recovery.toml", "/etc/greetd/config.toml"}:
        _validate_greetd_config(entry.source, data, recovery=entry.target.endswith("config-tuigreet-recovery.toml"))
    elif entry.target == "/etc/greetd/regreet.toml":
        _validate_regreet_config(entry.source, data)


def _parse_toml(path: Path, data: bytes) -> dict:
    try:
        parsed = tomllib.loads(data.decode("utf-8"))
    except (tomllib.TOMLDecodeError, UnicodeError) as error:
        raise GreeterStageError(
            f"greeter TOML source {path} is invalid: {error}; no target changes were made; fix the repository config and rerun"
        ) from error
    if not isinstance(parsed, dict):
        raise GreeterStageError(f"greeter TOML source {path} did not parse to a table; no target changes were made")
    return parsed


def _validate_greetd_config(path: Path, data: bytes, recovery: bool) -> None:
    parsed = _parse_toml(path, data)
    if "initial_session" in parsed:
        raise GreeterStageError(f"greetd config {path} must not enable autologin; no target changes were made")
    terminal = parsed.get("terminal")
    default_session = parsed.get("default_session")
    if not isinstance(terminal, dict) or terminal.get("vt") != 1:
        raise GreeterStageError(f"greetd config {path} must set [terminal].vt = 1; no target changes were made")
    if not isinstance(default_session, dict) or default_session.get("user") != "greeter":
        raise GreeterStageError(f"greetd config {path} must run as the greeter system account; no target changes were made")
    command = default_session.get("command")
    expected = "tuigreet --time --remember --cmd Hyprland" if recovery else "cage -s -- /usr/lib/infinity-os/start-greeter"
    if command != expected:
        raise GreeterStageError(
            f"greetd config {path} has unexpected default session command; no target changes were made; restore the fixed greeter command"
        )


def _validate_regreet_config(path: Path, data: bytes) -> None:
    parsed = _parse_toml(path, data)
    background = parsed.get("background")
    gtk = parsed.get("GTK")
    appearance = parsed.get("appearance")
    commands = parsed.get("commands")
    if not isinstance(background, dict) or background.get("path") != "/usr/share/infinity-os/wallpapers/nocturne.svg" or background.get("fit") != "Cover":
        raise GreeterStageError(f"ReGreet config {path} must reference the fixed greeter wallpaper; no target changes were made")
    if not isinstance(gtk, dict) or not isinstance(gtk.get("font_name"), str) or not gtk.get("font_name"):
        raise GreeterStageError(f"ReGreet config {path} must define a GTK font; no target changes were made")
    if not isinstance(appearance, dict) or not isinstance(appearance.get("greeting_msg"), str) or not appearance.get("greeting_msg"):
        raise GreeterStageError(f"ReGreet config {path} must define a greeting message; no target changes were made")
    if not isinstance(commands, dict):
        raise GreeterStageError(f"ReGreet config {path} must define command actions; no target changes were made")
    for name in ("reboot", "poweroff"):
        value = commands.get(name)
        if value != ["systemctl", name]:
            raise GreeterStageError(f"ReGreet config {path} has invalid {name} command; no target changes were made")


def _validate_manifest(root: Path) -> dict[str, bytes]:
    seen: set[str] = set()
    sources: dict[str, bytes] = {}
    for entry in MANIFEST:
        if entry.target not in ALLOWLIST:
            raise GreeterStageError(f"greeter target {entry.target!r} is outside the fixed allowlist; no target changes were made")
        if entry.target in seen:
            raise GreeterStageError(f"duplicate greeter target {entry.target!r}; no target changes were made; fix the fixed manifest")
        seen.add(entry.target)
        destination = _target(root, entry.target)
        _require_safe_target_ancestors(root, destination)
        _read_target_regular(root, destination)
        sources[entry.target] = _source_bytes(entry)
    _require_safe_target_ancestors(root, _target(root, BACKUP_DIRECTORY) / ".probe")
    _require_safe_target_ancestors(root, _target(root, DISPLAY_MANAGER))
    return sources


def _default_package_validator(root: Path) -> tuple[str, ...]:
    database = root / "var/lib/pacman/local"
    try:
        entries = tuple(path for path in database.iterdir() if path.is_dir())
    except OSError as error:
        raise GreeterStageError(
            f"cannot inspect target pacman database at {database}: {error}; no target changes were made; install required packages first"
        ) from error
    installed = set()
    for entry in entries:
        try:
            installed.add(_pacman_local_name(root, entry))
        except GreeterStageError:
            raise
        except (OSError, UnicodeError, ValueError) as error:
            raise GreeterStageError(
                f"cannot inspect pacman package metadata at {entry / 'desc'}: {error}; no target changes were made; repair the pacman local database and rerun"
            ) from error
    missing = []
    for package in REQUIRED_PACKAGES:
        if package not in installed:
            missing.append(package)
    return tuple(missing)


def _pacman_local_name(root: Path, package_directory: Path) -> str:
    desc_path = package_directory / "desc"
    try:
        content = read_existing_regular(root, desc_path).decode("utf-8")
    except (OSError, UnicodeError, ValueError) as error:
        raise GreeterStageError(
            f"cannot read pacman package metadata at {desc_path}: {error}; no target changes were made; repair the pacman local database and rerun"
        ) from error
    lines = content.splitlines()
    for index, line in enumerate(lines):
        if line == "%NAME%":
            if index + 1 >= len(lines) or not lines[index + 1].strip():
                raise GreeterStageError(
                    f"pacman package metadata at {desc_path} has an empty %NAME% field; no target changes were made; repair the pacman local database and rerun"
                )
            return lines[index + 1].strip()
    raise GreeterStageError(
        f"pacman package metadata at {desc_path} is missing a %NAME% field; no target changes were made; repair the pacman local database and rerun"
    )


def _default_account_validator(root: Path) -> bool:
    if root == Path("/"):
        try:
            pwd.getpwnam("greeter")
            return True
        except KeyError:
            return False
    passwd = root / "etc/passwd"
    try:
        content = read_existing_regular(root, passwd).decode("utf-8")
    except (OSError, UnicodeError, ValueError) as error:
        raise GreeterStageError(
            f"cannot inspect greeter account in {passwd}: {error}; no target changes were made; install greetd sysusers data first"
        ) from error
    return any(line.split(":", 1)[0] == "greeter" for line in content.splitlines())


def _require_regular_file(root: Path, absolute_path: str, description: str) -> bytes:
    destination = _target(root, absolute_path)
    try:
        return read_existing_regular(root, destination)
    except (OSError, ValueError) as error:
        raise GreeterStageError(
            f"required {description} is missing or unsafe at {destination}: {error}; no target changes were made; install the owning package and rerun"
        ) from error


def _require_executable(root: Path, absolute_path: str) -> None:
    destination = _target(root, absolute_path)
    _require_regular_file(root, absolute_path, f"executable {absolute_path}")
    try:
        metadata = destination.stat(follow_symlinks=False)
    except OSError as error:
        raise GreeterStageError(
            f"required executable {absolute_path} is missing or unsafe at {destination}: {error}; no target changes were made; install the owning package and rerun"
        ) from error
    if not stat.S_ISREG(metadata.st_mode) or stat.S_IMODE(metadata.st_mode) & 0o111 == 0:
        raise GreeterStageError(
            f"required executable {absolute_path} at {destination} has no execute bit; no target changes were made; reinstall the owning package or restore executable permissions"
        )


def _validate_supporting_system(root: Path, checks: PreflightChecks) -> None:
    package_validator = checks.package_validator or _default_package_validator
    missing_packages = package_validator(root)
    if missing_packages:
        names = ", ".join(missing_packages)
        raise GreeterStageError(
            f"missing required greeter packages: {names}; no target changes were made; install the official desktop-shell and wayland package groups first"
        )
    for executable in REQUIRED_EXECUTABLES:
        _require_executable(root, executable)
    account_validator = checks.account_validator or _default_account_validator
    if not account_validator(root):
        raise GreeterStageError(
            "required greeter system account is absent; no target changes were made; install greetd and apply its sysusers configuration first"
        )
    session = _parse_desktop_entry(root, HYPRLAND_SESSION)
    desktop_entry = session["Desktop Entry"]
    if desktop_entry.get("Name") != "Hyprland" or desktop_entry.get("Exec") != "Hyprland" or desktop_entry.get("Type") != "Application":
        raise GreeterStageError(
            f"Hyprland session file at {_target(root, HYPRLAND_SESSION)} is not usable; no target changes were made; reinstall hyprland"
        )
    _require_regular_file(root, GREETD_UNIT, "greetd systemd unit")
    try:
        validate_symlink(root, _target(root, DISPLAY_MANAGER), GREETD_UNIT)
    except (OSError, ValueError) as error:
        raise GreeterStageError(
            f"display-manager.service is already owned by another selection; no target changes were made; disable or move the conflicting file before rerunning: {error}"
        ) from error


def _parse_desktop_entry(root: Path, absolute_path: str) -> configparser.ConfigParser:
    data = _require_regular_file(root, absolute_path, "Hyprland Wayland session")
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    try:
        text = data.decode("utf-8")
        parser.read_string(text, source=str(_target(root, absolute_path)))
    except (UnicodeError, configparser.Error) as error:
        raise GreeterStageError(
            f"Hyprland session file at {_target(root, absolute_path)} is malformed: {error}; no target changes were made; reinstall hyprland"
        ) from error
    if "Desktop Entry" not in parser:
        raise GreeterStageError(
            f"Hyprland session file at {_target(root, absolute_path)} is missing [Desktop Entry]; no target changes were made; reinstall hyprland"
        )
    return parser


def validate(root: Path, checks: PreflightChecks = PreflightChecks()) -> None:
    try:
        resolved = resolve_root(str(root))
    except (OSError, ValueError) as error:
        raise GreeterStageError(f"cannot resolve greeter target root {root}: {error}") from error
    _validate_manifest(resolved)
    _validate_supporting_system(resolved, checks)


def _backup_path(root: Path, destination: Path) -> Path:
    backup_root = _target(root, BACKUP_DIRECTORY)
    relative_name = "__".join(destination.relative_to(root).parts)
    candidate = backup_root / f"{relative_name}.bak"
    suffix = 1
    while candidate.exists() or candidate.is_symlink():
        candidate = backup_root / f"{relative_name}.bak.{suffix}"
        suffix += 1
    return candidate


@contextmanager
def _transaction_lock(root: Path):
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise GreeterStageError(
                f"another greeter transaction is already active for {root}; no target changes were made; wait for it to finish and rerun"
            ) from error
        try:
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)


def _rollback(steps: list[Callable[[], None]], cause: BaseException) -> None:
    failures = []
    for undo in reversed(steps):
        try:
            undo()
        except (OSError, GreeterStageError, ValueError) as error:
            failures.append(str(error))
    if failures:
        detail = "; ".join(failures)
        raise GreeterStageError(
            f"greeter transaction failed and rollback needs manual repair: {cause}; rollback errors: {detail}"
        ) from cause
    raise GreeterStageError(f"greeter transaction failed; completed target changes were rolled back in reverse order: {cause}") from cause


def _restore_backup(root: Path, destination: Path, current: tuple[bytes, int], backup: Path) -> None:
    atomic_write(root, destination, current[0], current[1])
    remove_regular(root, backup)


def _write_entry(root: Path, entry: ManifestEntry, data: bytes, undo_steps: list[Callable[[], None]]) -> GreeterResult:
    destination = _target(root, entry.target)
    current = _read_target_regular(root, destination)
    if current is not None and current[0] == data and current[1] == entry.mode:
        return GreeterResult(destination, "unchanged")
    backup = None
    if current is not None:
        backup = _backup_path(root, destination)
        undo_steps.append(
            lambda destination=destination, current=current, backup=backup: _restore_backup(root, destination, current, backup)
        )
        atomic_write(root, backup, current[0], current[1])
    else:
        undo_steps.append(lambda destination=destination: remove_regular(root, destination))
    atomic_write(root, destination, data, entry.mode)
    if current is None:
        return GreeterResult(destination, "created", backup)
    return GreeterResult(destination, "updated", backup)


def _ensure_display_manager(root: Path, undo_steps: list[Callable[[], None]]) -> GreeterResult:
    destination = _target(root, DISPLAY_MANAGER)
    created = [False]
    undo_steps.append(lambda destination=destination, created=created: _remove_symlink(root, destination) if created[0] else None)
    status = ensure_symlink(root, destination, GREETD_UNIT)
    if status == "existing":
        return GreeterResult(destination, "unchanged")
    created[0] = True
    return GreeterResult(destination, "created")


def apply(root: Path, checks: PreflightChecks = PreflightChecks()) -> tuple[GreeterResult, ...]:
    try:
        resolved = resolve_root(str(root))
    except (OSError, ValueError) as error:
        raise GreeterStageError(f"cannot resolve greeter target root {root}: {error}") from error
    with _transaction_lock(resolved):
        sources = _validate_manifest(resolved)
        _validate_supporting_system(resolved, checks)
        undo_steps: list[Callable[[], None]] = []
        results: list[GreeterResult] = []
        try:
            for entry in MANIFEST:
                results.append(_write_entry(resolved, entry, sources[entry.target], undo_steps))
            results.append(_ensure_display_manager(resolved, undo_steps))
        except (OSError, GreeterStageError, ValueError) as error:
            _rollback(undo_steps, error)
        return tuple(results)


def plan() -> None:
    for entry in MANIFEST:
        print(f"PLAN greeter: {entry.source.relative_to(REPO)} -> {entry.target} mode {entry.mode:04o}")
    print(f"PLAN greeter: {DISPLAY_MANAGER} -> {GREETD_UNIT} (created last)")
    print("PLAN greeter: validates packages, executables, greeter account, Hyprland session, and display-manager conflicts before writing")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["plan", "validate", "apply"])
    parser.add_argument("--target-root", default="/")
    arguments = parser.parse_args()
    try:
        if arguments.action == "plan":
            plan()
            return 0
        root = Path(arguments.target_root)
        if arguments.action == "validate":
            validate(root)
            return 0
        for result in apply(root):
            backup = f" backup={result.backup}" if result.backup is not None else ""
            print(f"greeter: {result.status} {result.target}{backup}")
        return 0
    except (OSError, GreeterStageError, ValueError) as error:
        print(f"greeter: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
