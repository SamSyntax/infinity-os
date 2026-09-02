#!/usr/bin/python3
from __future__ import annotations

import os
import shutil
import stat
import sys
import tempfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "installation/lib"))

from source_bundle import (  # noqa: E402
    BUNDLE_ID,
    INSTALL,
    MKDIR,
    MV,
    FileMetadata,
    SourceBundleError,
    build_source_bundle,
    discover_source_paths,
    promotion_plan,
    promotion_plan_or_reuse,
    render_tofu,
    verify_promoted_bundle,
)


class RootOwnedPolicy:
    def metadata(self, path: Path) -> FileMetadata:
        data = os.stat(path, follow_symlinks=False)
        mode = data.st_mode
        if stat.S_ISREG(mode):
            kind = "file"
        elif stat.S_ISDIR(mode):
            kind = "directory"
        elif stat.S_ISLNK(mode):
            kind = "symlink"
        else:
            kind = "other"
        return FileMetadata(stat.S_IMODE(mode), 0, 0, data.st_ino, data.st_nlink, kind)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def require_failure(action, expected: str) -> None:
    try:
        action()
    except SourceBundleError as error:
        require(expected in str(error), f"error did not mention {expected!r}: {error}")
        return
    raise SystemExit(f"expected failure containing {expected!r}")


def copy_bundle(bundle, destination: Path) -> None:
    for entry in bundle.entries:
        source = bundle.repo / entry.path
        target = destination / entry.path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(entry.mode)


def test_closure_and_manifest() -> None:
    paths = {path.as_posix() for path in discover_source_paths(REPO)}
    required = {
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
        "deployment/mappings.tsv",
        "system/packages/base.official.txt",
        "system/packages/hardware.official.txt",
        "system/packages/wayland.official.txt",
        "system/packages/desktop-shell.official.txt",
        "system/packages/applications.official.txt",
        "system/services/enabled-system-units.tsv",
        "system/services/greetd.toml",
        "system/services/greetd-tuigreet-recovery.toml",
        "desktop/greeter/start-greeter",
        "desktop/greeter/regreet.toml",
        "desktop/greeter/regreet.css",
        "desktop/greeter/shell.qml",
        "desktop/themes/schema.json",
        "desktop/wallpapers/nocturne.svg",
        "desktop/hypr/hyprland.lua",
        "desktop/quickshell/shell.qml",
        "user/shell.json",
    }
    require(required <= paths, f"source closure omitted {sorted(required - paths)}")
    forbidden_prefixes = (".git/", ".runtime/", ".omo/", ".opencode/", "tests/", "docs/", "specs/")
    require(not any(path.startswith(forbidden_prefixes) for path in paths), "source closure included excluded repository areas")
    require(not any(path.endswith((".md", ".markdown", ".rst")) for path in paths), "source closure included documentation files")
    require("system/packages/graphics.official.txt" not in paths, "source closure included deferred graphics manifest")
    require("system/packages/aur.txt" not in paths, "source closure included AUR manifest")

    bundle = build_source_bundle(REPO)
    require(BUNDLE_ID.fullmatch(bundle.bundle_id) is not None, "bundle id is not a sha256 hex digest")
    require(bundle.entries == tuple(sorted(bundle.entries, key=lambda entry: entry.path)), "bundle entries are not sorted")
    modes = {entry.path: entry.mode for entry in bundle.entries}
    require(modes["install.sh"] == 0o755, "install.sh did not receive executable mode")
    require(modes["bin/infinity-theme"] == 0o755, "bin runtime did not receive executable mode")
    require(modes["desktop/greeter/start-greeter"] == 0o755, "greeter launcher did not receive executable mode")
    require(modes["installation/lib/safe_fs.py"] == 0o644, "library did not receive regular file mode")


def test_tofu_and_promotion_plan() -> None:
    bundle = build_source_bundle(REPO)
    tofu = render_tofu(bundle, REPO, "tester")
    require(f"Bundle ID: {bundle.bundle_id}" in tofu, "TOFU text omitted bundle id")
    require(f"INSTALL {bundle.bundle_id} AS tester" in tofu, "TOFU text omitted exact confirmation")
    plan = promotion_plan(bundle)
    require(plan.final == f"/opt/infinity-os/sources/{bundle.bundle_id}", "promotion final path is wrong")
    allowed = {INSTALL, MKDIR, MV}
    require(all(operation.argv[0] in allowed for operation in plan.operations), "promotion plan used a non-allowlisted command")
    require(all(operation.argv[0].startswith("/usr/bin/") for operation in plan.operations), "promotion commands are not absolute /usr/bin paths")
    install_ops = [operation.argv for operation in plan.operations if operation.argv[0] == INSTALL]
    require(len(install_ops) == len(bundle.entries), "promotion plan did not emit one install per file")
    require(all("sudo" not in item and "systemctl" not in item and "pacman" not in item for op in plan.operations for item in op.argv), "promotion plan included privileged orchestration commands")


def test_promoted_verification_and_reuse() -> None:
    bundle = build_source_bundle(REPO)
    with tempfile.TemporaryDirectory(prefix="infinity-source-bundle-") as tmp:
        promoted_root = Path(tmp)
        promoted = promoted_root / bundle.bundle_id
        copy_bundle(bundle, promoted)
        verify_promoted_bundle(bundle, promoted, RootOwnedPolicy())
        reuse = promotion_plan_or_reuse(bundle, promoted_root, RootOwnedPolicy())
        require(reuse.status == "reuse" and not reuse.operations, "existing verified bundle was not reused")

        first = promoted / bundle.entries[0].path
        first.write_bytes(first.read_bytes() + b"changed")
        require_failure(lambda: verify_promoted_bundle(bundle, promoted, RootOwnedPolicy()), "digest mismatch")
        require_failure(lambda: promotion_plan_or_reuse(bundle, promoted_root, RootOwnedPolicy()), "collision")


def test_promoted_rejects_unexpected_symlink_and_hardlink() -> None:
    bundle = build_source_bundle(REPO)
    with tempfile.TemporaryDirectory(prefix="infinity-source-bundle-bad-") as tmp:
        promoted = Path(tmp) / bundle.bundle_id
        copy_bundle(bundle, promoted)
        unexpected = promoted / "unexpected.txt"
        unexpected.write_text("bad\n", encoding="utf-8")
        require_failure(lambda: verify_promoted_bundle(bundle, promoted, RootOwnedPolicy()), "unexpected promoted file")
        unexpected.unlink()

        link = promoted / "linked"
        link.symlink_to(promoted / bundle.entries[0].path)
        require_failure(lambda: verify_promoted_bundle(bundle, promoted, RootOwnedPolicy()), "symlink")
        link.unlink()

        first = promoted / bundle.entries[0].path
        second = promoted / bundle.entries[1].path
        second.unlink()
        os.link(first, second)
        require_failure(lambda: verify_promoted_bundle(bundle, promoted, RootOwnedPolicy()), "metadata")


def main() -> None:
    test_closure_and_manifest()
    test_tofu_and_promotion_plan()
    test_promoted_verification_and_reuse()
    test_promoted_rejects_unexpected_symlink_and_hardlink()
    print("ok: source bundle fingerprint, promotion plan, and verification")


if __name__ == "__main__":
    main()
