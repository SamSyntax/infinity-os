#!/usr/bin/python3
from __future__ import annotations

import argparse
import errno
import hashlib
import json
import os
import re
import stat
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Protocol

from safe_fs import validate_relative, validate_user


REPO = Path(__file__).resolve().parents[2]
PROMOTED_ROOT = PurePosixPath("/opt/infinity-os/sources")
INSTALL = "/usr/bin/install"
MKDIR = "/usr/bin/mkdir"
MV = "/usr/bin/mv"
OFFICIAL_PACKAGE_MANIFESTS = (
    "system/packages/base.official.txt",
    "system/packages/hardware.official.txt",
    "system/packages/wayland.official.txt",
    "system/packages/desktop-shell.official.txt",
    "system/packages/applications.official.txt",
)
FIXED_RUNTIME_FILES = (
    "install.sh",
    "bin/infinity-deploy",
    "bin/infinity-theme",
    "bin/infinity-validate",
    "bin/infinity-capture-screenshot",
    "installation/lib/installer.sh",
    "installation/lib/package_selection.py",
    "installation/lib/safe_fs.py",
    "installation/lib/source_bundle.py",
    "installation/stages/greeter.py",
    "installation/stages/services.py",
)
SERVICE_GREETER_INPUTS = (
    "system/services/enabled-system-units.tsv",
    "system/services/greetd-tuigreet-recovery.toml",
    "system/services/greetd.toml",
    "desktop/greeter/start-greeter",
    "desktop/greeter/regreet.toml",
    "desktop/greeter/regreet.css",
    "desktop/greeter/shell.qml",
)
THEME_ROOTS = ("desktop/themes", "desktop/wallpapers")
EXCLUDED_PARTS = frozenset((".git", ".runtime", ".omo", ".opencode", "__pycache__", ".pytest_cache", ".mypy_cache"))
EXCLUDED_TOP_LEVEL = frozenset(("tests", "docs", "specs"))
SECRET_NAME = re.compile(r"(?:secret|token|credential|password|passwd|cookie|id_rsa|id_ed25519)", re.IGNORECASE)
BUNDLE_ID = re.compile(r"^[0-9a-f]{64}$")
DOC_SUFFIXES = frozenset((".md", ".markdown", ".rst"))


class SourceBundleError(ValueError):
    pass


@dataclass(frozen=True, order=True)
class BundleEntry:
    path: str
    mode: int
    size: int
    sha256: str


@dataclass(frozen=True)
class SourceBundle:
    repo: Path
    entries: tuple[BundleEntry, ...]
    bundle_id: str

    def manifest_json(self) -> str:
        return canonical_manifest(self.entries)


@dataclass(frozen=True)
class PromotionOperation:
    argv: tuple[str, ...]


@dataclass(frozen=True)
class PromotionPlan:
    bundle_id: str
    stage: str
    final: str
    operations: tuple[PromotionOperation, ...]
    status: str = "promote"


@dataclass(frozen=True)
class FileMetadata:
    mode: int
    uid: int
    gid: int
    inode: int
    nlink: int
    kind: str


class MetadataPolicy(Protocol):
    def metadata(self, path: Path) -> FileMetadata: ...


class OsMetadataPolicy:
    def metadata(self, path: Path) -> FileMetadata:
        try:
            data = os.stat(path, follow_symlinks=False)
        except OSError as error:
            raise SourceBundleError(
                f"cannot inspect promoted path {path}: {error}; impact: trusted bundle verification stopped before privileged orchestration; recovery: promote the confirmed bundle again"
            ) from error
        mode = data.st_mode
        if stat.S_ISREG(mode):
            kind = "file"
        elif stat.S_ISDIR(mode):
            kind = "directory"
        elif stat.S_ISLNK(mode):
            kind = "symlink"
        else:
            kind = "other"
        return FileMetadata(stat.S_IMODE(mode), data.st_uid, data.st_gid, data.st_ino, data.st_nlink, kind)


def _relative(value: str) -> Path:
    try:
        relative = validate_relative(value)
    except ValueError as error:
        raise SourceBundleError(
            f"unsafe source path {value!r}; impact: source bundle was not trusted; recovery: keep bundle inputs repository-relative with no traversal"
        ) from error
    if relative.parts[0] in EXCLUDED_TOP_LEVEL or any(part in EXCLUDED_PARTS for part in relative.parts) or SECRET_NAME.search(relative.name):
        raise SourceBundleError(
            f"excluded source path {value!r}; impact: source bundle was not trusted; recovery: remove caches, tests, docs, specs, tooling, or secret-like files from the fixed closure"
        )
    return relative


def _entry_mode(relative: Path) -> int:
    first = relative.parts[0]
    if first == "bin" or relative == Path("install.sh") or relative == Path("desktop/greeter/start-greeter"):
        return 0o755
    return 0o644


def _open_dir_at(parent_fd: int, part: str, path: Path) -> int:
    try:
        return os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent_fd)
    except OSError as error:
        raise SourceBundleError(
            f"unsafe or missing source directory {path}: {error}; impact: source bundle was not trusted; recovery: restore a real repository directory and rerun"
        ) from error


def _open_source_file(repo: Path, relative: Path) -> tuple[bytes, int]:
    root_fd = os.open(repo, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    fd = root_fd
    try:
        for index, part in enumerate(relative.parts[:-1]):
            next_fd = _open_dir_at(fd, part, repo.joinpath(*relative.parts[: index + 1]))
            os.close(fd)
            fd = next_fd
        try:
            file_fd = os.open(relative.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        except OSError as error:
            if error.errno == errno.ELOOP:
                raise SourceBundleError(
                    f"refusing symlinked source {relative}; impact: source bundle was not trusted; recovery: replace it with a real regular file"
                ) from error
            raise SourceBundleError(
                f"cannot open source {relative}: {error}; impact: source bundle was not trusted; recovery: restore the file and rerun"
            ) from error
        try:
            metadata = os.fstat(file_fd)
            if not stat.S_ISREG(metadata.st_mode):
                raise SourceBundleError(
                    f"refusing non-regular source {relative}; impact: source bundle was not trusted; recovery: replace it with a regular file"
                )
            if metadata.st_nlink != 1:
                raise SourceBundleError(
                    f"refusing hardlinked source {relative}; impact: source bundle was not trusted; recovery: copy it to an unlinked regular file and rerun"
                )
            chunks = []
            while True:
                chunk = os.read(file_fd, 1024 * 1024)
                if not chunk:
                    break
                chunks.append(chunk)
            content = b"".join(chunks)
            if not content:
                raise SourceBundleError(
                    f"refusing empty source {relative}; impact: source bundle was not trusted; recovery: restore expected content and rerun"
                )
            return content, metadata.st_size
        finally:
            os.close(file_fd)
    finally:
        os.close(fd)


def _is_regular_path(repo: Path, relative: Path) -> bool:
    try:
        metadata = os.stat(repo / relative, follow_symlinks=False)
    except OSError as error:
        raise SourceBundleError(
            f"cannot inspect source {relative}: {error}; impact: source bundle was not trusted; recovery: restore the repository file and rerun"
        ) from error
    if stat.S_ISLNK(metadata.st_mode):
        raise SourceBundleError(
            f"refusing symlinked source {relative}; impact: source bundle was not trusted; recovery: replace it with a real file or directory"
        )
    return stat.S_ISREG(metadata.st_mode)


def _walk_source_tree(repo: Path, relative: Path) -> tuple[Path, ...]:
    root = repo / relative
    try:
        metadata = os.stat(root, follow_symlinks=False)
    except OSError as error:
        raise SourceBundleError(
            f"cannot inspect source root {relative}: {error}; impact: source bundle was not trusted; recovery: restore the repository path and rerun"
        ) from error
    if stat.S_ISLNK(metadata.st_mode):
        raise SourceBundleError(f"refusing symlinked source root {relative}; impact: source bundle was not trusted; recovery: replace it with a real directory")
    if stat.S_ISREG(metadata.st_mode):
        return (relative,)
    if not stat.S_ISDIR(metadata.st_mode):
        raise SourceBundleError(f"refusing non-directory source root {relative}; impact: source bundle was not trusted; recovery: restore a regular file or directory")
    files: list[Path] = []
    for directory, dirs, names in os.walk(root, topdown=True, followlinks=False):
        current = Path(directory)
        current_relative = current.relative_to(repo)
        dirs[:] = sorted(name for name in dirs if name not in EXCLUDED_PARTS)
        for dirname in dirs:
            child = current_relative / dirname
            child_metadata = os.stat(repo / child, follow_symlinks=False)
            if not stat.S_ISDIR(child_metadata.st_mode):
                raise SourceBundleError(f"refusing unsafe source directory {child}; impact: source bundle was not trusted; recovery: remove symlinks or special files from mapped directories")
        for name in sorted(names):
            child = current_relative / name
            if child.suffix.lower() in DOC_SUFFIXES:
                continue
            _relative(child.as_posix())
            if _is_regular_path(repo, child):
                files.append(child)
            else:
                raise SourceBundleError(f"refusing non-regular source {child}; impact: source bundle was not trusted; recovery: remove special files from mapped directories")
    return tuple(files)


def parse_deployment_mapping_sources(repo: Path) -> tuple[Path, ...]:
    path = Path("deployment/mappings.tsv")
    content, _ = _open_source_file(repo, path)
    sources: list[Path] = []
    seen_targets: set[str] = set()
    for line_number, raw_line in enumerate(content.decode("utf-8").splitlines(), 1):
        if not raw_line.strip() or raw_line.startswith("#"):
            continue
        fields = raw_line.split("\t")
        if len(fields) != 4:
            raise SourceBundleError(f"invalid mapping at deployment/mappings.tsv:{line_number}; impact: source bundle was not trusted; recovery: use source, target, mode, preserve tab fields")
        source, target, mode_text, preserve = fields
        source_relative = _relative(source)
        target_relative = _relative(target)
        if target in seen_targets:
            raise SourceBundleError(f"duplicate deployment target {target!r}; impact: source bundle was not trusted; recovery: make deployment targets unique")
        seen_targets.add(target)
        if mode_text not in {"0644", "0755"}:
            raise SourceBundleError(f"unsafe deployment mode {mode_text!r}; impact: source bundle was not trusted; recovery: use fixed 0644 or 0755 modes")
        if preserve not in {"yes", "no"}:
            raise SourceBundleError(f"invalid deployment preserve flag {preserve!r}; impact: source bundle was not trusted; recovery: use yes or no")
        if target_relative.parts[0] not in {".config", ".local", "etc", "usr"}:
            raise SourceBundleError(f"deployment target {target!r} is outside allowed roots; impact: source bundle was not trusted; recovery: keep mappings under user config/data or fixed system roots")
        sources.extend(_walk_source_tree(repo, source_relative))
    return tuple(sources)


def discover_source_paths(repo: Path = REPO) -> tuple[Path, ...]:
    candidates: list[Path] = []
    for item in (*FIXED_RUNTIME_FILES, *OFFICIAL_PACKAGE_MANIFESTS, *SERVICE_GREETER_INPUTS, "deployment/mappings.tsv"):
        candidates.append(_relative(item))
    for root in THEME_ROOTS:
        candidates.extend(_walk_source_tree(repo, _relative(root)))
    candidates.extend(parse_deployment_mapping_sources(repo))
    unique = sorted(set(candidates), key=lambda value: value.as_posix())
    return tuple(unique)


def canonical_manifest(entries: tuple[BundleEntry, ...]) -> str:
    rows = [
        {"mode": f"{entry.mode:04o}", "path": entry.path, "sha256": entry.sha256, "size": entry.size}
        for entry in sorted(entries, key=lambda item: item.path)
    ]
    return json.dumps(rows, sort_keys=True, separators=(",", ":")) + "\n"


def build_source_bundle(repo: Path = REPO) -> SourceBundle:
    resolved = repo.resolve(strict=True)
    entries: list[BundleEntry] = []
    for relative in discover_source_paths(resolved):
        content, size = _open_source_file(resolved, relative)
        entries.append(BundleEntry(relative.as_posix(), _entry_mode(relative), size, hashlib.sha256(content).hexdigest()))
    ordered = tuple(sorted(entries, key=lambda item: item.path))
    bundle_id = hashlib.sha256(canonical_manifest(ordered).encode("utf-8")).hexdigest()
    return SourceBundle(resolved, ordered, bundle_id)


def tofu_confirmation(bundle: SourceBundle, target_user: str) -> str:
    user = validate_user(target_user)
    return f"INSTALL {bundle.bundle_id} AS {user}"


def render_tofu(bundle: SourceBundle, source_path: Path, target_user: str) -> str:
    return "\n".join([
        f"Source path: {source_path.resolve(strict=True)}",
        f"Bundle ID: {bundle.bundle_id}",
        f"Target user: {validate_user(target_user)}",
        "Type exactly to trust these bytes:",
        tofu_confirmation(bundle, target_user),
    ]) + "\n"


def _absolute_bundle_path(bundle_id: str) -> PurePosixPath:
    if BUNDLE_ID.fullmatch(bundle_id) is None:
        raise SourceBundleError(f"invalid bundle id {bundle_id!r}; impact: promotion plan was not created; recovery: recompute the source bundle")
    return PROMOTED_ROOT / bundle_id


def promotion_plan(bundle: SourceBundle, stage_suffix: str = ".stage") -> PromotionPlan:
    final = _absolute_bundle_path(bundle.bundle_id)
    stage = PROMOTED_ROOT / f".{bundle.bundle_id}{stage_suffix}"
    operations: list[PromotionOperation] = [PromotionOperation((MKDIR, "-p", str(stage)))]
    directories = sorted({str(stage / PurePosixPath(entry.path).parent) for entry in bundle.entries if PurePosixPath(entry.path).parent != PurePosixPath(".")})
    for directory in directories:
        operations.append(PromotionOperation((MKDIR, "-p", directory)))
    for entry in bundle.entries:
        source = str(bundle.repo / entry.path)
        destination = str(stage / PurePosixPath(entry.path))
        operations.append(PromotionOperation((INSTALL, "-o", "root", "-g", "root", "-m", f"{entry.mode:04o}", source, destination)))
    operations.append(PromotionOperation((MV, str(stage), str(final))))
    return PromotionPlan(bundle.bundle_id, str(stage), str(final), tuple(operations))


def _safe_relative_under(root: Path, path: Path) -> Path:
    try:
        return path.relative_to(root)
    except ValueError as error:
        raise SourceBundleError(f"promoted path {path} escapes {root}; impact: trusted bundle verification stopped; recovery: inspect the promoted source tree manually") from error


def _read_promoted_file(root: Path, relative: Path) -> bytes:
    return _open_source_file(root, relative)[0]


def verify_promoted_bundle(bundle: SourceBundle, promoted: Path, policy: MetadataPolicy | None = None) -> None:
    metadata_policy = policy or OsMetadataPolicy()
    root_metadata = metadata_policy.metadata(promoted)
    if root_metadata.kind != "directory" or root_metadata.uid != 0 or root_metadata.gid != 0 or root_metadata.mode & 0o022:
        raise SourceBundleError(f"promoted bundle root {promoted} is not root-owned safe directory; impact: privileged orchestration was not run; recovery: remove it and promote the confirmed bundle again")
    expected = {Path(entry.path): entry for entry in bundle.entries}
    observed: set[Path] = set()
    for directory, dirs, names in os.walk(promoted, topdown=True, followlinks=False):
        current = Path(directory)
        current_metadata = metadata_policy.metadata(current)
        if current_metadata.kind != "directory" or current_metadata.uid != 0 or current_metadata.gid != 0 or current_metadata.mode & 0o022:
            raise SourceBundleError(f"unsafe promoted directory {current}; impact: privileged orchestration was not run; recovery: remove the bundle and promote it again")
        for dirname in list(dirs):
            child = current / dirname
            child_metadata = metadata_policy.metadata(child)
            if child_metadata.kind == "symlink":
                raise SourceBundleError(f"refusing symlink in promoted bundle {child}; impact: privileged orchestration was not run; recovery: remove the bundle and promote it again")
            if child_metadata.kind != "directory":
                raise SourceBundleError(f"refusing non-directory in promoted bundle {child}; impact: privileged orchestration was not run; recovery: remove the bundle and promote it again")
        for name in names:
            child = current / name
            relative = _safe_relative_under(promoted, child)
            file_metadata = metadata_policy.metadata(child)
            if file_metadata.kind == "symlink":
                raise SourceBundleError(f"refusing symlink in promoted bundle {relative}; impact: privileged orchestration was not run; recovery: remove the bundle and promote it again")
            if file_metadata.kind != "file":
                raise SourceBundleError(f"refusing non-regular promoted path {relative}; impact: privileged orchestration was not run; recovery: remove the bundle and promote it again")
            if relative not in expected:
                raise SourceBundleError(f"unexpected promoted file {relative}; impact: privileged orchestration was not run; recovery: remove the bundle and promote the confirmed manifest again")
            entry = expected[relative]
            if file_metadata.uid != 0 or file_metadata.gid != 0 or file_metadata.mode != entry.mode or file_metadata.nlink != 1:
                raise SourceBundleError(f"unsafe promoted file metadata for {relative}; impact: privileged orchestration was not run; recovery: remove the bundle and promote it again")
            content = _read_promoted_file(promoted, relative)
            if len(content) != entry.size or hashlib.sha256(content).hexdigest() != entry.sha256:
                raise SourceBundleError(f"promoted file digest mismatch for {relative}; impact: privileged orchestration was not run; recovery: remove the bundle and promote the confirmed bytes again")
            observed.add(relative)
    missing = sorted(path.as_posix() for path in set(expected) - observed)
    if missing:
        raise SourceBundleError(f"promoted bundle is missing files {missing}; impact: privileged orchestration was not run; recovery: promote the confirmed bundle again")


def promotion_plan_or_reuse(bundle: SourceBundle, promoted_root: Path, policy: MetadataPolicy | None = None) -> PromotionPlan:
    destination = promoted_root / bundle.bundle_id
    if destination.exists() or destination.is_symlink():
        try:
            verify_promoted_bundle(bundle, destination, policy)
        except SourceBundleError as error:
            raise SourceBundleError(f"existing bundle id collision at {destination}: {error}; impact: promotion was not planned and privileged orchestration must not run; recovery: inspect or remove the conflicting tree") from error
        return PromotionPlan(bundle.bundle_id, str(destination) + ".stage", str(destination), tuple(), "reuse")
    return promotion_plan(bundle)


def _print_plan(plan: PromotionPlan) -> None:
    print(json.dumps({
        "bundleId": plan.bundle_id,
        "status": plan.status,
        "stage": plan.stage,
        "final": plan.final,
        "operations": [list(operation.argv) for operation in plan.operations],
    }, indent=2, sort_keys=True))


def main() -> int:
    parser = argparse.ArgumentParser(prog="source_bundle.py")
    parser.add_argument("--repo", type=Path, default=REPO)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("manifest")
    tofu = sub.add_parser("tofu")
    tofu.add_argument("--target-user", required=True)
    plan = sub.add_parser("plan")
    plan.add_argument("--promoted-root", type=Path, default=Path(str(PROMOTED_ROOT)))
    verify = sub.add_parser("verify")
    verify.add_argument("--promoted", type=Path, required=True)
    arguments = parser.parse_args()
    try:
        bundle = build_source_bundle(arguments.repo)
        if arguments.command == "manifest":
            print(json.dumps({"bundleId": bundle.bundle_id, "entries": [entry.__dict__ for entry in bundle.entries]}, indent=2, sort_keys=True))
            return 0
        if arguments.command == "tofu":
            print(render_tofu(bundle, bundle.repo, arguments.target_user), end="")
            return 0
        if arguments.command == "plan":
            _print_plan(promotion_plan_or_reuse(bundle, arguments.promoted_root))
            return 0
        verify_promoted_bundle(bundle, arguments.promoted)
        print(f"ok: promoted source bundle {bundle.bundle_id} verified")
        return 0
    except (OSError, UnicodeError, SourceBundleError, ValueError) as error:
        print(f"source bundle: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
