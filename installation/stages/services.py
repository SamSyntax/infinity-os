#!/usr/bin/python3
import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path


LIB = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB))

from safe_fs import (
    ensure_symlink,
    read_existing_regular,
    require_directory,
    require_trusted_root_path,
    resolve_root,
    validate_symlink,
)


UNIT_NAME = re.compile(r"^[A-Za-z0-9_.@:-]+\.service$")
TARGET_NAME = re.compile(r"^[A-Za-z0-9_.@:-]+\.target$")
DEFERRED = "greetd, sshd, portals, UPower, PipeWire, WirePlumber, and hypridle remain deferred"


class ServiceEnablementError(ValueError):
    pass


@dataclass(frozen=True)
class ServiceEntry:
    unit: str
    target: str
    package: str


@dataclass(frozen=True)
class ServiceResult:
    unit: str
    target: str
    destination: Path
    status: str


def parse_manifest(path: Path) -> tuple[ServiceEntry, ...]:
    entries = []
    seen = set()
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as error:
        raise ServiceEnablementError(f"cannot read service manifest {path}: {error}") from error
    for line_number, raw_line in enumerate(lines, 1):
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) != 3:
            raise ServiceEnablementError(f"invalid service manifest entry at {path}:{line_number}")
        unit, target, package = fields
        if not UNIT_NAME.fullmatch(unit) or not TARGET_NAME.fullmatch(target):
            raise ServiceEnablementError(
                f"invalid service or target name at {path}:{line_number}: {unit!r} {target!r}"
            )
        if unit in seen:
            raise ServiceEnablementError(f"duplicate service {unit!r} at {path}:{line_number}")
        seen.add(unit)
        if not re.fullmatch(r"[a-z0-9][a-z0-9@._+-]*", package):
            raise ServiceEnablementError(f"invalid package name at {path}:{line_number}: {package!r}")
        entries.append(ServiceEntry(unit, target, package))
    if not entries:
        raise ServiceEnablementError(f"service manifest is empty: {path}")
    return tuple(entries)


def destination_for(root: Path, entry: ServiceEntry) -> Path:
    return root / "etc/systemd/system" / f"{entry.target}.wants" / entry.unit


def source_for(root: Path, entry: ServiceEntry) -> Path:
    return root / "usr/lib/systemd/system" / entry.unit


def link_target_for(entry: ServiceEntry) -> str:
    return f"/usr/lib/systemd/system/{entry.unit}"


def require_offline_root(root: Path) -> None:
    if root == Path("/"):
        raise ServiceEnablementError("services require an offline target and refuse the live root /")
    for marker in [root / "run/systemd/system", root / "run/systemd/private"]:
        if marker.exists() or marker.is_symlink():
            raise ServiceEnablementError(
                f"services target {root} appears active because it contains systemd runtime state"
            )


def resolve_service_root(root: Path) -> Path:
    try:
        return resolve_root(str(root))
    except (OSError, ValueError) as error:
        raise ServiceEnablementError(f"cannot resolve service target root {root}: {error}") from error


def validate_resolved(root: Path, entries: tuple[ServiceEntry, ...]) -> None:
    resolved = root
    require_offline_root(resolved)
    system_directory = resolved / "etc/systemd/system"
    try:
        require_directory(resolved, system_directory)
    except OSError as error:
        raise ServiceEnablementError(
            f"target systemd configuration directory is missing or unsafe: {system_directory}: {error}"
        ) from error
    for entry in entries:
        source = source_for(resolved, entry)
        try:
            read_existing_regular(resolved, source)
        except OSError as error:
            raise ServiceEnablementError(
                f"required installed unit {entry.unit!r} is missing or unsafe at {source}: {error}"
            ) from error
        except ValueError as error:
            raise ServiceEnablementError(str(error)) from error
    for entry in entries:
        try:
            validate_symlink(resolved, destination_for(resolved, entry), link_target_for(entry))
        except (OSError, ValueError) as error:
            raise ServiceEnablementError(str(error)) from error


def validate(root: Path, entries: tuple[ServiceEntry, ...]) -> None:
    validate_resolved(resolve_service_root(root), entries)


def apply(root: Path, entries: tuple[ServiceEntry, ...]) -> tuple[ServiceResult, ...]:
    resolved = resolve_service_root(root)
    validate_resolved(resolved, entries)
    results = []
    for entry in entries:
        destination = destination_for(resolved, entry)
        try:
            status = ensure_symlink(resolved, destination, link_target_for(entry))
        except (OSError, ValueError) as error:
            raise ServiceEnablementError(
                f"cannot enable {entry.unit!r} at {destination}; earlier correct links were preserved and rerunning is safe: {error}"
            ) from error
        results.append(ServiceResult(entry.unit, entry.target, destination, status))
    return tuple(results)


def plan(entries: tuple[ServiceEntry, ...]) -> None:
    for entry in entries:
        print(f"PLAN services: {entry.unit} -> {entry.target} (package: {entry.package})")
    print(f"PLAN services: {DEFERRED}")
    print("PLAN services: writes only fixed boot links inside an offline target; no service process is controlled")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["plan", "validate", "apply"])
    parser.add_argument("--target-root", required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    arguments = parser.parse_args()
    try:
        entries = parse_manifest(arguments.manifest)
        if arguments.action == "plan":
            plan(entries)
            return 0
        root = Path(arguments.target_root)
        if os.geteuid() != 0:
            raise ServiceEnablementError("services validation and apply require root privileges")
        require_trusted_root_path(resolve_service_root(root))
        if arguments.action == "validate":
            validate(root, entries)
            return 0
        for result in apply(root, entries):
            print(f"services: {result.status} {result.unit} -> {result.destination}")
        print(f"services: complete; {DEFERRED}")
        return 0
    except (OSError, ServiceEnablementError, ValueError) as error:
        print(f"services: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
