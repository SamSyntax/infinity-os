#!/usr/bin/env python3
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
INSTALLER = REPO / "install.sh"


def run(*arguments):
    return subprocess.run(
        [str(INSTALLER), *arguments],
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

    with tempfile.TemporaryDirectory(prefix="infinity-installer-confirm-base-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "base")
        require(confirm.returncode != 0, confirm.stdout + confirm.stderr)
        require("selected stages are plan-only" in confirm.stderr and "base" in confirm.stderr, "base stage was not rejected")
        assert_empty_directory(tmp, "base stage confirm wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-confirm-preflight-") as tmp:
        confirm = run("--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "preflight")
        require(confirm.returncode == 0, confirm.stdout + confirm.stderr)
        require("STAGE preflight" in confirm.stdout, "preflight confirm did not run")

    with tempfile.TemporaryDirectory(prefix="infinity-installer-") as tmp:
        plan = run("--plan", "--target-root", tmp, "--target-user", "tester", "--stage", "preflight", "--stage", "themes")
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        require("STAGE preflight" in plan.stdout and "DRY-RUN apply theme" in plan.stdout, "plan output omitted selected actions")
        assert_empty_directory(tmp, "plan mode wrote into the target root")

    print("ok: installer help, plan, confirm rejection, and no-write behavior")


if __name__ == "__main__":
    main()
