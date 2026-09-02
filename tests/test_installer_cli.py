#!/usr/bin/python3
import os
import json
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
    require("preflight,packages,services,greeter,themes,deploy,validate,preview" in help_result.stdout, "installer help omits apply-capable greeter stage")
    require("packages/services/greeter/preview" in help_result.stdout, "installer help omits greeter sudo notice")

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
        require("target-user=previewer" in plan.stdout, "sudo default target user did not prefer SUDO_USER")
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

    with tempfile.TemporaryDirectory(prefix="infinity-installer-greeter-combo-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "greeter", "--stage", "preflight")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("greeter apply must be selected by itself" in confirm.stderr, "greeter apply combination was not rejected")
        assert_empty_directory(tmp, "rejected greeter combination wrote into the target root")

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

    with tempfile.TemporaryDirectory(prefix="infinity-installer-greeter-plan-") as tmp:
        plan = run("--plan", "--target-root", tmp, "--target-user", "tester", "--stage", "greeter")
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        for expected in ["PLAN greeter:", "display-manager.service", "validates packages"]:
            require(expected in plan.stdout, f"greeter plan omitted {expected!r}")
        assert_empty_directory(tmp, "greeter plan wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-greeter-confirm-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "greeter")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("greeter apply only supports --target-root /" in confirm.stderr, "greeter confirm did not reject non-live target root")
        assert_empty_directory(tmp, "rejected greeter confirm wrote into the target root")

    empty_greeter_root = run("--confirm", "--target-root", "", "--target-user", "tester", "--stage", "greeter")
    require(empty_greeter_root.returncode != 0, empty_greeter_root.stdout + empty_greeter_root.stderr)
    require("target root '' does not exist" in empty_greeter_root.stderr, "empty greeter target root was not rejected before apply")

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

    expected_greeter_snapshot_files = {
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
    }
    greeter_manifest = run_installer_function("INFINITY_REPO=$PWD; INFINITY_TARGET_USER=tester; infinity_greeter_snapshot_manifest_json")
    require(greeter_manifest.returncode == 0, greeter_manifest.stdout + greeter_manifest.stderr)
    greeter_manifest_json = json.loads(greeter_manifest.stdout)
    require(greeter_manifest_json["repo"] == str(REPO), "greeter snapshot manifest used the wrong repository")
    require(greeter_manifest_json["target_user"] == "tester", "greeter snapshot manifest used the wrong target user")
    require(set(greeter_manifest_json["files"]) == expected_greeter_snapshot_files, "greeter snapshot manifest did not use the fixed minimal allowlist")
    require(all(len(value) == 64 for value in greeter_manifest_json["files"].values()), "greeter snapshot manifest emitted invalid digests")

    mismatched_manifest_json = json.dumps(
        {
            "repo": str(REPO),
            "target_user": "tester",
            "files": {relative: "0" * 64 for relative in expected_greeter_snapshot_files},
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    bootstrap_mismatch_script = r'''
source "$1"
"$INFINITY_PYTHON" -c "$INFINITY_GREETER_SNAPSHOT_BOOTSTRAP" "$2"
'''
    bootstrap_mismatch = subprocess.run(
        ["/usr/bin/bash", "-c", bootstrap_mismatch_script, "bash", str(INSTALLER_LIB), mismatched_manifest_json],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(bootstrap_mismatch.returncode != 0, "greeter bootstrap accepted a digest mismatch")
    bootstrap_error = bootstrap_mismatch.stdout + bootstrap_mismatch.stderr
    require(
        "digest mismatch" in bootstrap_error or "source repository must be root-owned" in bootstrap_error,
        "forged greeter bootstrap manifest error was unclear",
    )

    with tempfile.TemporaryDirectory(prefix="infinity-installer-untrusted-source-") as tmp:
        untrusted_source = run_installer_function(
            'INFINITY_REPO=$2; infinity_validate_greeter_source_repository',
            tmp,
        )
        require(untrusted_source.returncode != 0, "world-writable-path greeter source repository was accepted")
        require("root-owned and not group/world-writable" in untrusted_source.stderr, "untrusted greeter source error was unclear")

    elevation_script = r'''
source "$1"
infinity_effective_uid() { printf '1000\n'; }
infinity_preview_preflight() { printf 'PREFLIGHT\n'; }
infinity_exec_sudo() {
  printf 'SUDO\n'
  printf '%s\n' "$@"
  return 73
}
infinity_compute_preview_argv() { printf 'PRIVILEGED-WORK-REACHED\n'; return 99; }
infinity_installer_main --confirm --target-root / --target-user tester --stage preview
'''
    elevation = subprocess.run(
        ["/usr/bin/bash", "-c", elevation_script, "bash", str(INSTALLER_LIB)],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(elevation.returncode == 73, f"preview did not return the elevation result:\n{elevation.stdout}{elevation.stderr}")
    require(
        elevation.stdout.splitlines()
        == [
            "PREFLIGHT",
            "SUDO",
            str(INSTALLER),
            "--confirm",
            "--target-root",
            "/",
            "--target-user",
            "tester",
            "--stage",
            "preview",
        ],
        f"preview elevation did not preserve canonical arguments:\n{elevation.stdout}",
    )
    require("PRIVILEGED-WORK-REACHED" not in elevation.stdout, "preview continued into privileged work after requesting elevation")

    greeter_elevation_script = r'''
source "$1"
infinity_effective_uid() { printf '1000\n'; }
infinity_greeter_preflight() { printf 'PREFLIGHT\n'; }
infinity_validate_greeter_source_repository() { :; }
infinity_exec_sudo() {
  printf 'SUDO\n'
  printf 'ARGC=%s\n' "$#"
  printf 'ARG0=%s\n' "$1"
  printf 'ARG1=%s\n' "$2"
  case "$3" in
    *'INFINITY_GREETER_TRUSTED_SNAPSHOT'*) printf 'BOOTSTRAP_HAS_MARKER\n' ;;
  esac
  case "$3" in
    *'shutil.rmtree(snapshot)'*) printf 'BOOTSTRAP_HAS_CLEANUP\n' ;;
  esac
  case "$3" in
    *'"/usr/bin/bash", str(snapshot / "install.sh"), "--confirm", "--target-root", "/", "--target-user", target_user, "--stage", "greeter"'*) printf 'BOOTSTRAP_HAS_CHILD_ARGV\n' ;;
  esac
  printf 'JSON=%s\n' "$4"
  return 73
}
infinity_prewrite_greeter_validation() { printf 'PRIVILEGED-WORK-REACHED\n'; return 99; }
infinity_installer_main --confirm --target-root / --target-user tester --stage greeter
'''
    greeter_elevation = subprocess.run(
        ["/usr/bin/bash", "-c", greeter_elevation_script, "bash", str(INSTALLER_LIB)],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(greeter_elevation.returncode == 73, f"greeter did not return the elevation result:\n{greeter_elevation.stdout}{greeter_elevation.stderr}")
    require(
        greeter_elevation.stdout.splitlines()[:5] == ["PREFLIGHT", "SUDO", "ARGC=4", "ARG0=/usr/bin/python3", "ARG1=-c"],
        f"greeter elevation did not preserve canonical arguments:\n{greeter_elevation.stdout}",
    )
    require("BOOTSTRAP_HAS_MARKER" in greeter_elevation.stdout, "greeter sudo bootstrap did not carry the trusted snapshot marker logic")
    require("BOOTSTRAP_HAS_CLEANUP" in greeter_elevation.stdout, "greeter sudo bootstrap did not carry cleanup intent")
    require("BOOTSTRAP_HAS_CHILD_ARGV" in greeter_elevation.stdout, "greeter sudo bootstrap did not carry canonical child argv")
    greeter_elevation_json_line = next(line for line in greeter_elevation.stdout.splitlines() if line.startswith("JSON="))
    greeter_elevation_json = json.loads(greeter_elevation_json_line.removeprefix("JSON="))
    require(greeter_elevation_json["repo"] == str(REPO), "greeter sudo JSON used the wrong repository")
    require(greeter_elevation_json["target_user"] == "tester", "greeter sudo JSON used the wrong target user")
    require(set(greeter_elevation_json["files"]) == expected_greeter_snapshot_files, "greeter sudo JSON did not use the fixed allowlist")
    require("PRIVILEGED-WORK-REACHED" not in greeter_elevation.stdout, "greeter continued into privileged work after requesting elevation")

    greeter_direct_root_script = r'''
source "$1"
infinity_effective_uid() { printf '0\n'; }
INFINITY_LOG_RELATIVE=$2
infinity_prewrite_greeter_validation() { printf 'PRIVILEGED-WORK-REACHED\n'; return 99; }
infinity_run_stage() { printf 'RUN-REACHED\n'; }
infinity_installer_main --confirm --target-root / --target-user tester --stage greeter
'''
    with tempfile.TemporaryDirectory(prefix="infinity-installer-greeter-direct-root-") as tmp:
        log_relative = str(Path(tmp) / "install.log").lstrip("/")
        greeter_direct_root = subprocess.run(
            ["/usr/bin/bash", "-c", greeter_direct_root_script, "bash", str(INSTALLER_LIB), log_relative],
            cwd=REPO,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    require(greeter_direct_root.returncode != 0, "direct root greeter apply without a trusted snapshot was accepted")
    require("verified trusted snapshot" in greeter_direct_root.stderr, "direct root greeter refusal did not explain the trusted snapshot requirement")
    require("PRIVILEGED-WORK-REACHED" not in greeter_direct_root.stdout and "RUN-REACHED" not in greeter_direct_root.stdout, "direct root greeter apply reached privileged work after marker failure")

    greeter_ordering_script = r'''
source "$1"
infinity_effective_uid() { printf '0\n'; }
infinity_greeter_preflight() { printf 'PREFLIGHT\n'; }
INFINITY_LOG_RELATIVE=$2
infinity_prewrite_greeter_validation() { printf 'VALIDATE %s %s %s %s\n' "$INFINITY_PYTHON" "$INFINITY_REPO/installation/stages/greeter.py" validate "$INFINITY_TARGET_ROOT"; }
infinity_run_stage() { printf 'RUN %s\n' "$1"; }
infinity_log() { printf 'LOG %s\n' "$1"; }
infinity_installer_main --confirm --target-root / --target-user tester --stage greeter
'''
    with tempfile.TemporaryDirectory(prefix="infinity-installer-greeter-ordering-") as tmp:
        log_relative = str(Path(tmp) / "install.log").lstrip("/")
        greeter_ordering = subprocess.run(
            ["/usr/bin/bash", "-c", greeter_ordering_script, "bash", str(INSTALLER_LIB), log_relative],
            cwd=REPO,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    require(greeter_ordering.returncode == 0, greeter_ordering.stdout + greeter_ordering.stderr)
    ordering_lines = greeter_ordering.stdout.splitlines()
    require(
        ordering_lines[:3] == ["PREFLIGHT", f"VALIDATE /usr/bin/python3 {REPO / 'installation/stages/greeter.py'} validate /", "RUN greeter"],
        f"greeter validate/log/run ordering was wrong:\n{greeter_ordering.stdout}",
    )
    require("LOG DONE" in ordering_lines, "greeter main did not finish after dispatch")

    greeter_dispatch_script = r'''
source "$1"
INFINITY_REPO=$PWD
INFINITY_TARGET_ROOT=/
INFINITY_TARGET_USER=tester
INFINITY_DRY_RUN=0
infinity_log() { :; }
infinity_log_command() {
  printf 'COMMAND\n'
  printf '%s\n' "$@"
}
infinity_run_stage greeter
'''
    greeter_dispatch = subprocess.run(
        ["/usr/bin/bash", "-c", greeter_dispatch_script, "bash", str(INSTALLER_LIB)],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(greeter_dispatch.returncode == 0, greeter_dispatch.stdout + greeter_dispatch.stderr)
    require(
        greeter_dispatch.stdout.splitlines()
        == ["COMMAND", "/usr/bin/python3", str(REPO / "installation/stages/greeter.py"), "apply", "--target-root", "/"],
        f"greeter dispatch argv was wrong:\n{greeter_dispatch.stdout}",
    )

    validation_script = r'''
source "$1"
INFINITY_REPO=$PWD
INFINITY_TARGET_USER=tester
infinity_effective_uid() { printf '0\n'; }
infinity_exec_as_target_user() {
  printf '%s\n' "$@"
}
infinity_prewrite_repository_validation
'''
    validation = subprocess.run(
        ["/usr/bin/bash", "-c", validation_script, "bash", str(INSTALLER_LIB)],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(validation.returncode == 0, validation.stdout + validation.stderr)
    require(
        validation.stdout.splitlines() == ["tester", str(REPO / "bin/infinity-validate")],
        f"elevated preview validation did not drop to the target user:\n{validation.stdout}",
    )

    preview_user_commands_script = r'''
source "$1"
INFINITY_REPO=$PWD
INFINITY_TARGET_ROOT=/
INFINITY_TARGET_USER=tester
INFINITY_DRY_RUN=0
infinity_preview_preflight() { :; }
infinity_log() { :; }
infinity_log_command() {
  printf 'COMMAND\n'
  printf '%s\n' "$@"
}
infinity_preview_success() { :; }
infinity_run_stage preview
'''
    preview_user_commands = subprocess.run(
        ["/usr/bin/bash", "-c", preview_user_commands_script, "bash", str(INSTALLER_LIB)],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(preview_user_commands.returncode == 0, preview_user_commands.stdout + preview_user_commands.stderr)
    expected_user_prefix = ["COMMAND", "infinity_exec_as_target_user", "tester"]
    command_groups = preview_user_commands.stdout.split("COMMAND\n")[1:]
    require(len(command_groups) == 3, f"preview did not emit package, deploy, and theme commands:\n{preview_user_commands.stdout}")
    for group in command_groups[1:]:
        require(
            ["COMMAND", *group.splitlines()[:2]] == expected_user_prefix,
            f"preview deploy/theme command did not drop to the target user:\n{group}",
        )
    require("chown" not in preview_user_commands.stdout, "preview retained broad recursive ownership repair")

    print("ok: installer help, plan, confirm rejection, and no-write behavior")


if __name__ == "__main__":
    main()
