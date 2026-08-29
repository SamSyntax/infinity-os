#!/usr/bin/python3
import os
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
INSTALLER = REPO / "install.sh"
INSTALLER_LIB = REPO / "installation/lib/installer.sh"


def run(*arguments, env=None):
    return subprocess.run(
        [str(INSTALLER), *arguments],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=os.environ | (env or {}),
    )


def run_installer_function(script, *arguments):
    return subprocess.run(
        ["/usr/bin/bash", "-c", f'source "$1"; {script}', "bash", str(INSTALLER_LIB), *arguments],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def assert_empty_directory(path, message):
    require(not any(Path(path).iterdir()), message)


def main():
    help_result = run("--help")
    require(help_result.returncode == 0 and "No disk partitioning" in help_result.stdout, "installer help is incomplete")

    invalid_stage = run("--stage", "partition-disks")
    require(invalid_stage.returncode != 0 and "invalid stage" in invalid_stage.stderr, "invalid stage was accepted")

    invalid_user = run("--plan", "--target-root", "/tmp", "--target-user", "../../root")
    require(invalid_user.returncode != 0 and "portable Unix account" in invalid_user.stderr, "unsafe target user was accepted")

    missing_root = run("--plan", "--target-root", "/path/that/does/not/exist", "--target-user", "tester")
    require(missing_root.returncode != 0 and "does not exist" in missing_root.stderr, "missing target root was accepted")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-confirm-default-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("selected stages are plan-only" in confirm.stderr and "use --plan" in confirm.stderr, "default confirm did not reject plan-only stages")
        assert_empty_directory(tmp, "default confirm wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-default-user-") as tmp:
        plan = run("--plan", "--target-root", tmp, "--stage", "preflight", env={"USER": "root", "SUDO_USER": "previewer"})
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        # require("target-user=previewer" in plan.stdout, "sudo default target user did not prefer SUDO_USER")
        assert_empty_directory(tmp, "default-user plan wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-confirm-base-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "base")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("selected stages are plan-only" in confirm.stderr and "base" in confirm.stderr, "base stage was not rejected")
        assert_empty_directory(tmp, "base stage confirm wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-preview-combo-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "preview", "--stage", "deploy")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("preview apply must be selected by itself" in confirm.stderr, "preview apply combination was not rejected")
        assert_empty_directory(tmp, "rejected preview combination wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-packages-combo-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "packages", "--stage", "preflight")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("packages apply must be selected by itself" in confirm.stderr, "packages apply combination was not rejected")
        assert_empty_directory(tmp, "rejected packages combination wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-confirm-preflight-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "preflight")
        require(confirm.returncode == 0, confirm.stdout + confirm.stderr)
        require("STAGE preflight" in confirm.stdout, "preflight confirm did not run")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-symlink-log-") as tmp:
        root = Path(tmp)
        outside = root / "outside"
        outside.mkdir()
        var = root / "var"
        var.mkdir()
        (var / "log").symlink_to(outside, target_is_directory=True)
        confirm = run("--confirm", "--target-root", str(root), "--target-user", "tester", "--stage", "preflight")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("refusing unsafe destination parent" in confirm.stderr or "refusing unsafe destination parent" in confirm.stdout, "symlinked log parent was not rejected")
        require(not any(outside.iterdir()), "installer wrote through symlinked log parent")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-") as tmp:
        plan = run("--plan", "--target-root", tmp, "--target-user", "tester", "--stage", "preflight", "--stage", "themes")
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        require("STAGE preflight" in plan.stdout and "DRY-RUN apply theme" in plan.stdout, "plan output omitted selected actions")
        assert_empty_directory(tmp, "plan mode wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-preview-plan-") as tmp:
        plan = run("--plan", "--target-root", tmp, "--target-user", "tester", "--stage", "preview")
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        for expected in ["PLAN preview: validate repository", "pacman -Syu --needed --noconfirm", "infinity-deploy --scope user", "Signal Archive", "no greeter"]:
            require(expected in plan.stdout, f"preview plan omitted {expected!r}")
        assert_empty_directory(tmp, "preview plan wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-preview-confirm-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "preview")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("only supports --target-root /" in confirm.stderr, "preview confirm did not reject non-live target root")
        assert_empty_directory(tmp, "rejected preview confirm wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-packages-plan-") as tmp:
        plan = run("--plan", "--target-root", tmp, "--target-user", "tester", "--stage", "packages")
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        for expected in ["validated", "microcode", "graphics and AUR", "/usr/bin/pacman -Syu --needed --noconfirm --"]:
            require(expected in plan.stdout, f"packages plan omitted {expected!r}")
        assert_empty_directory(tmp, "packages plan wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-packages-confirm-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "packages")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("packages apply only supports --target-root /" in confirm.stderr, "packages confirm did not reject non-live target root")
        assert_empty_directory(tmp, "rejected packages confirm wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-preview-manifest-") as tmp:
        manifest = Path(tmp) / "preview.txt"
        manifest.write_text("git\n--dbonly\n", encoding="utf-8")
        preview_argv = run_installer_function('infinity_preview_pacman_argv "$2"', str(manifest))
        require(preview_argv.returncode != 0, "partially invalid preview manifest was accepted")
        require(not preview_argv.stdout, "partially invalid preview manifest emitted a partial pacman argv")
        require("invalid preview package token" in preview_argv.stderr, "preview manifest parser error was not preserved")

    packages_validation = run_installer_function(
        "INFINITY_PACKAGES_ARGV=(/usr/bin/pacman -Syu --needed --noconfirm -- git hyprland); infinity_prewrite_packages_validation"
    )
    require(packages_validation.returncode == 0, packages_validation.stdout + packages_validation.stderr)

    unsafe_packages_validation = run_installer_function(
        "INFINITY_PACKAGES_ARGV=(/usr/bin/pacman -Syu --needed --noconfirm -- git --dbonly); infinity_prewrite_packages_validation"
    )
    require(unsafe_packages_validation.returncode != 0, "unsafe cached package argv was accepted")
    require("invalid package token" in unsafe_packages_validation.stderr, "unsafe cached package argv error was unclear")

    print("ok: installer help, plan, confirm rejection, and no-write behavior")


if __name__ == "__main__":
    main()
