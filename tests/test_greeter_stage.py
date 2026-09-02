#!/usr/bin/env python3
import importlib.util
import errno
import fcntl
import os
import sys
import tempfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
GREETER_STAGE = REPO / "installation/stages/greeter.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_greeter_stage():
    spec = importlib.util.spec_from_file_location("infinity_greeter", GREETER_STAGE)
    require(spec is not None and spec.loader is not None, "greeter stage module cannot be loaded")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_file(path: Path, content: str = "ok\n", mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(mode)


def write_package(root: Path, package: str, directory_name: str | None = None) -> None:
    package_directory = root / "var/lib/pacman/local" / (directory_name or f"{package}-1.0-1")
    write_file(package_directory / "desc", f"%NAME%\n{package}\n%VERSION%\n1.0-1\n")


def make_target(root: Path, greeter) -> None:
    for package in greeter.REQUIRED_PACKAGES:
        write_package(root, package)
    for executable in greeter.REQUIRED_EXECUTABLES:
        write_file(root.joinpath(*Path(executable).parts[1:]), "#!/usr/bin/sh\n", 0o755)
    write_file(root / "etc/passwd", "root:x:0:0:root:/root:/usr/bin/bash\ngreeter:x:972:972:greetd greeter:/var/lib/greetd:/usr/bin/nologin\n")
    write_file(root / "usr/share/wayland-sessions/hyprland.desktop", "[Desktop Entry]\nName=Hyprland\nExec=Hyprland\nType=Application\n")
    write_file(root / "usr/lib/systemd/system/greetd.service", "[Unit]\nDescription=greetd\n")
    (root / "etc/systemd/system").mkdir(parents=True, exist_ok=True)


def target_path(root: Path, absolute_path: str) -> Path:
    return root.joinpath(*Path(absolute_path).parts[1:])


def manifest_targets(root: Path, greeter) -> list[Path]:
    return [target_path(root, entry.target) for entry in greeter.MANIFEST]


def display_manager(root: Path, greeter) -> Path:
    return target_path(root, greeter.DISPLAY_MANAGER)


def backup_root(root: Path, greeter) -> Path:
    return target_path(root, greeter.BACKUP_DIRECTORY)


def assert_manifest_content(root: Path, greeter) -> None:
    for entry in greeter.MANIFEST:
        destination = target_path(root, entry.target)
        require(destination.read_bytes() == entry.source.read_bytes(), f"wrong greeter deployment content for {entry.target}")
        mode = destination.stat().st_mode & 0o777
        require(mode == entry.mode, f"wrong mode for {entry.target}: {mode:o}")


def assert_no_manifest_mutation(root: Path, greeter) -> None:
    require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "preflight failure wrote target files")
    require(not display_manager(root, greeter).exists() and not display_manager(root, greeter).is_symlink(), "preflight failure selected a display manager")


def run_with_bad_source(greeter, root: Path, target: str, data: bytes) -> str:
    original_source_bytes = greeter._source_bytes

    def bad_source(entry):
        if entry.target == target:
            greeter._validate_source_semantics(entry, data)
            return data
        return original_source_bytes(entry)

    greeter._source_bytes = bad_source
    try:
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            return str(error)
    finally:
        greeter._source_bytes = original_source_bytes
    raise SystemExit(f"greeter apply accepted malformed source for {target}")


def main() -> None:
    greeter = load_greeter_stage()

    require(
        [(entry.source.relative_to(REPO).as_posix(), entry.target, entry.mode) for entry in greeter.MANIFEST]
        == [
            ("system/services/greetd-tuigreet-recovery.toml", "/etc/greetd/config-tuigreet-recovery.toml", 0o644),
            ("desktop/greeter/start-greeter", "/usr/lib/infinity-os/start-greeter", 0o755),
            ("desktop/greeter/regreet.toml", "/etc/greetd/regreet.toml", 0o644),
            ("desktop/greeter/regreet.css", "/etc/greetd/regreet.css", 0o644),
            ("desktop/greeter/shell.qml", "/usr/share/infinity-os/greeter/shell.qml", 0o644),
            ("desktop/wallpapers/nocturne.svg", "/usr/share/infinity-os/wallpapers/nocturne.svg", 0o644),
            ("system/services/greetd.toml", "/etc/greetd/config.toml", 0o644),
        ],
        "greeter manifest order changed unexpectedly",
    )
    for entry in greeter.MANIFEST:
        require(entry.source.is_file() and entry.source.read_bytes(), f"greeter manifest source is missing or empty: {entry.source}")

    try:
        greeter._require_safe_target_ancestors(Path("/"), Path("/tmp/infinity-greeter-untrusted-parent/config.toml"))
    except greeter.GreeterStageError as error:
        require("untrusted greeter destination parent" in str(error), "live-root writable-parent error was unclear")
    else:
        raise SystemExit("greeter accepted a world-writable live-root target ancestor")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-preflight-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        conflict = display_manager(root, greeter)
        conflict.symlink_to("/usr/lib/systemd/system/sddm.service")
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("display-manager.service" in str(error) and "no target changes were made" in str(error), "display conflict error was not actionable")
        else:
            raise SystemExit("greeter apply accepted a non-greetd display manager")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "late preflight conflict left deployed files")
        require(not backup_root(root, greeter).exists(), "preflight conflict created a backup or transaction artifact")
        require(os.readlink(conflict) == "/usr/lib/systemd/system/sddm.service", "conflicting display-manager link was modified")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-apply-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        results = greeter.apply(root)
        require([result.target for result in results] == [*manifest_targets(root, greeter), display_manager(root, greeter)], "greeter deployment order was not manifest order with symlink last")
        require([result.status for result in results] == ["created"] * 8, "first greeter apply did not create every target")
        assert_manifest_content(root, greeter)
        link = display_manager(root, greeter)
        require(link.is_symlink() and os.readlink(link) == greeter.GREETD_UNIT, "greeter did not create the exact display-manager symlink")
        second = greeter.apply(root)
        require([result.status for result in second] == ["unchanged"] * 8, "identical greeter rerun was not a no-op")
        require(not backup_root(root, greeter).exists(), "identical greeter rerun created unnecessary backups")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-backup-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        old_config = target_path(root, "/etc/greetd/config.toml")
        write_file(old_config, "old greetd config\n", 0o600)
        results = greeter.apply(root)
        config_result = next(result for result in results if result.target == old_config)
        require(config_result.status == "updated" and config_result.backup is not None, "changed existing config was not reported as backed up")
        require(config_result.backup.read_text(encoding="utf-8") == "old greetd config\n", "backup did not preserve original config content")
        require((config_result.backup.stat().st_mode & 0o777) == 0o600, "backup did not preserve original config mode")
        require(old_config.read_bytes() == (REPO / "system/services/greetd.toml").read_bytes(), "primary greeter config was not replaced after backup")
        backup_count = len(list(backup_root(root, greeter).glob("*")))
        second = greeter.apply(root)
        require([result.status for result in second] == ["unchanged"] * 8, "post-backup rerun was not unchanged")
        require(len(list(backup_root(root, greeter).glob("*"))) == backup_count, "unchanged rerun created another backup")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-managed-conflict-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        conflict = target_path(root, "/etc/greetd/regreet.css")
        conflict.parent.mkdir(parents=True)
        conflict.symlink_to("/tmp/outside.css")
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("no target changes were made" in str(error), "managed symlink conflict error did not promise preservation")
        else:
            raise SystemExit("greeter apply replaced a managed symlink conflict")
        require(conflict.is_symlink() and os.readlink(conflict) == "/tmp/outside.css", "managed symlink conflict was modified")
        require(not target_path(root, "/etc/greetd/config-tuigreet-recovery.toml").exists(), "managed conflict left an earlier deployment")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-fifo-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        fifo = target_path(root, "/etc/greetd/regreet.css")
        fifo.parent.mkdir(parents=True)
        os.mkfifo(fifo)
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("non-regular greeter destination" in str(error) and "no target changes were made" in str(error), "FIFO destination error was unclear")
        else:
            raise SystemExit("greeter apply accepted a FIFO managed destination")
        require(fifo.exists() and not fifo.is_file(), "FIFO managed destination was modified")
        require(not target_path(root, "/etc/greetd/config-tuigreet-recovery.toml").exists(), "FIFO preflight left an earlier deployment")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-missing-package-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        checks = greeter.PreflightChecks(package_validator=lambda checked_root: ("greetd",), account_validator=lambda checked_root: True)
        try:
            greeter.apply(root, checks)
        except greeter.GreeterStageError as error:
            require("missing required greeter packages: greetd" in str(error), "injected package preflight error was unclear")
        else:
            raise SystemExit("greeter apply accepted injected missing packages")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "package preflight failure wrote target files")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-package-prefix-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        for path in (root / "var/lib/pacman/local").iterdir():
            if path.name.startswith("greetd-"):
                for child in path.iterdir():
                    child.unlink()
                path.rmdir()
        write_package(root, "greetd-regreet", "greetd-9.9-9")
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("missing required greeter packages: greetd" in str(error), "package prefix collision did not report missing greetd")
        else:
            raise SystemExit("greeter package preflight accepted greetd-regreet metadata as greetd")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "package prefix failure wrote target files")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-package-desc-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        desc = root / "var/lib/pacman/local/greetd-1.0-1/desc"
        desc.write_text("%VERSION%\n1.0-1\n", encoding="utf-8")
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("missing a %NAME% field" in str(error) and "no target changes were made" in str(error), "malformed pacman metadata error was unclear")
        else:
            raise SystemExit("greeter package preflight accepted malformed pacman metadata")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "malformed package metadata wrote target files")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-executable-mode-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        non_executable = root / "usr/bin/regreet"
        non_executable.chmod(0o644)
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("has no execute bit" in str(error) and "no target changes were made" in str(error), "non-executable regular file error was unclear")
        else:
            raise SystemExit("greeter executable preflight accepted a non-executable regular file")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "non-executable preflight failure wrote target files")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-missing-account-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        (root / "etc/passwd").write_text("root:x:0:0:root:/root:/usr/bin/bash\n", encoding="utf-8")
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("greeter system account" in str(error), "missing account error was unclear")
        else:
            raise SystemExit("greeter apply accepted a missing greeter account")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "account preflight failure wrote target files")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-session-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        (root / "usr/share/wayland-sessions/hyprland.desktop").write_text("[Not Desktop Entry]\nComment=Name=Hyprland Exec=Hyprland Type=Application\n", encoding="utf-8")
        try:
            greeter.apply(root)
        except greeter.GreeterStageError as error:
            require("Hyprland session" in str(error), "invalid Hyprland session error was unclear")
        else:
            raise SystemExit("greeter apply accepted an unusable Hyprland session")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "session preflight failure wrote target files")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-bad-config-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        error = run_with_bad_source(greeter, root, "/etc/greetd/config.toml", b"[default_session]\ncommand = 'Hyprland'\nuser = 'greeter'\n")
        require("[terminal].vt = 1" in error and "no target changes were made" in error, "malformed primary greetd config error was unclear")
        assert_no_manifest_mutation(root, greeter)

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-autologin-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        error = run_with_bad_source(
            greeter,
            root,
            "/etc/greetd/config.toml",
            b"[terminal]\nvt = 1\n[default_session]\ncommand = 'cage -s -- /usr/lib/infinity-os/start-greeter'\nuser = 'greeter'\n[initial_session]\ncommand = 'Hyprland'\nuser = 'root'\n",
        )
        require("must not enable autologin" in error, "initial_session was not rejected explicitly")
        assert_no_manifest_mutation(root, greeter)

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-bad-recovery-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        error = run_with_bad_source(greeter, root, "/etc/greetd/config-tuigreet-recovery.toml", b"[terminal]\nvt = 1\n[default_session]\ncommand = 'cage -s -- bad'\nuser = 'greeter'\n")
        require("unexpected default session command" in error and "no target changes were made" in error, "malformed recovery greetd config error was unclear")
        assert_no_manifest_mutation(root, greeter)

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-bad-regreet-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        error = run_with_bad_source(greeter, root, "/etc/greetd/regreet.toml", b"[background]\npath = '/tmp/wrong.svg'\nfit = 'Cover'\n")
        require("ReGreet config" in error and "no target changes were made" in error, "malformed ReGreet config error was unclear")
        assert_no_manifest_mutation(root, greeter)

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-lock-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            try:
                greeter.apply(root)
            except greeter.GreeterStageError as error:
                require("another greeter transaction" in str(error) and "no target changes were made" in str(error), "concurrent lock error was unclear")
            else:
                raise SystemExit("greeter apply ignored an active transaction lock")
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)
        assert_no_manifest_mutation(root, greeter)

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-parent-preserve-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        preexisting = root / "usr/share/infinity-os/greeter"
        preexisting.mkdir(parents=True)
        original_symlink = greeter.os.symlink

        def failing_symlink(target: str, link_name: Path, *args, **kwargs) -> None:
            if Path(link_name).name == "display-manager.service":
                raise OSError("synthetic final symlink failure")
            original_symlink(target, link_name, *args, **kwargs)

        greeter.os.symlink = failing_symlink
        try:
            try:
                greeter.apply(root)
            except greeter.GreeterStageError:
                pass
            else:
                raise SystemExit("greeter apply succeeded despite injected final symlink failure")
        finally:
            greeter.os.symlink = original_symlink
        require(preexisting.is_dir(), "rollback removed a pre-existing empty parent directory")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-link-fsync-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        original_ensure_symlink = greeter.ensure_symlink
        original_fsync = greeter.os.fsync

        def ensure_with_failed_fsync(checked_root: Path, destination: Path, target: str) -> str:
            fsync_calls = 0

            def failing_first_fsync(fd: int) -> None:
                nonlocal fsync_calls
                fsync_calls += 1
                if fsync_calls == 1:
                    raise OSError(errno.EIO, "synthetic parent fsync failure")
                original_fsync(fd)

            greeter.os.fsync = failing_first_fsync
            try:
                return original_ensure_symlink(checked_root, destination, target)
            finally:
                greeter.os.fsync = original_fsync

        greeter.ensure_symlink = ensure_with_failed_fsync
        try:
            try:
                greeter.apply(root)
            except greeter.GreeterStageError as error:
                require("removed the created symlink" in str(error) and "rolled back in reverse order" in str(error), "post-symlink-fsync rollback error was unclear")
            else:
                raise SystemExit("greeter apply accepted a failed display-manager fsync")
        finally:
            greeter.ensure_symlink = original_ensure_symlink
            greeter.os.fsync = original_fsync
        require(not display_manager(root, greeter).exists() and not display_manager(root, greeter).is_symlink(), "failed symlink fsync left display-manager link")
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "failed symlink fsync left deployed files")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-rollback-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        removed: list[Path] = []
        original_remove_regular = greeter.remove_regular
        original_symlink = greeter.os.symlink

        def recording_remove(checked_root: Path, destination: Path) -> None:
            removed.append(destination.relative_to(checked_root))
            original_remove_regular(checked_root, destination)

        def failing_symlink(target: str, link_name: Path, *args, **kwargs) -> None:
            if Path(link_name).name == "display-manager.service":
                raise OSError("synthetic final symlink failure")
            original_symlink(target, link_name, *args, **kwargs)

        greeter.remove_regular = recording_remove
        greeter.os.symlink = failing_symlink
        try:
            try:
                greeter.apply(root)
            except greeter.GreeterStageError as error:
                require("rolled back in reverse order" in str(error), "rollback error did not describe recovery")
            else:
                raise SystemExit("greeter apply succeeded despite injected final symlink failure")
        finally:
            greeter.remove_regular = original_remove_regular
            greeter.os.symlink = original_symlink
        require(
            [path.as_posix() for path in removed]
            == [
                "etc/greetd/config.toml",
                "usr/share/infinity-os/wallpapers/nocturne.svg",
                "usr/share/infinity-os/greeter/shell.qml",
                "etc/greetd/regreet.css",
                "etc/greetd/regreet.toml",
                "usr/lib/infinity-os/start-greeter",
                "etc/greetd/config-tuigreet-recovery.toml",
            ],
            f"rollback did not remove created files in reverse manifest order: {[path.as_posix() for path in removed]}",
        )
        require(all(not path.exists() and not path.is_symlink() for path in manifest_targets(root, greeter)), "rollback left deployed files")
        require(not display_manager(root, greeter).exists() and not display_manager(root, greeter).is_symlink(), "rollback left display-manager selection")

    with tempfile.TemporaryDirectory(prefix="infinity-greeter-restore-failure-") as tmp:
        root = Path(tmp)
        make_target(root, greeter)
        config = target_path(root, "/etc/greetd/config.toml")
        original = b"original config retained for recovery\n"
        config.parent.mkdir(parents=True)
        config.write_bytes(original)
        original_atomic_write = greeter.atomic_write
        original_symlink = greeter.os.symlink

        def failing_restore(checked_root: Path, destination: Path, data: bytes, mode: int) -> None:
            if destination == config and data == original:
                raise OSError(errno.ENOSPC, "synthetic restore failure")
            original_atomic_write(checked_root, destination, data, mode)

        def failing_final_symlink(target: str, link_name: Path, *args, **kwargs) -> None:
            if Path(link_name).name == "display-manager.service":
                raise OSError(errno.EIO, "synthetic final symlink failure")
            os.symlink(target, link_name, *args, **kwargs)

        greeter.atomic_write = failing_restore
        greeter.os.symlink = failing_final_symlink
        try:
            try:
                greeter.apply(root)
            except greeter.GreeterStageError as error:
                require("rollback needs manual repair" in str(error), "restore failure did not request manual repair")
            else:
                raise SystemExit("greeter apply succeeded despite synthetic restore failure")
        finally:
            greeter.atomic_write = original_atomic_write
            greeter.os.symlink = original_symlink
        backups = list(backup_root(root, greeter).glob("etc__greetd__config.toml.bak*"))
        require(len(backups) == 1 and backups[0].read_bytes() == original, "failed restoration deleted the only recovery backup")

    source = GREETER_STAGE.read_text(encoding="utf-8")
    for forbidden in ["subprocess", "os.system", "Popen(", "--now", " start ", " restart "]:
        require(forbidden not in source, f"greeter implementation contains forbidden process-control token {forbidden!r}")

    print("ok: greeter preflight, deployment order, conflicts, idempotency, backups, symlink, and rollback")


if __name__ == "__main__":
    main()
