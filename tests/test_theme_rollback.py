#!/usr/bin/python3
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

def run_theme_with_fault(root):
    return subprocess.run(
        [
            sys.executable,
            str(REPO / "bin/infinity-theme"),
            "apply",
            "aurora",
            "--target-root",
            str(root),
            "--target-user",
            "testuser",
            "--test-fail-after",
            "1",
        ],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

def main():
    with tempfile.TemporaryDirectory(prefix="infinity-theme-hyprland-") as tmp:
        root = Path(tmp)
        passwd = root / "etc/passwd"
        passwd.parent.mkdir()
        passwd.write_text(
            f"testuser:x:{os.geteuid()}:{os.getegid()}:Test User:/home/testuser:/bin/bash\n",
            encoding="utf-8",
        )
        result = subprocess.run(
            [sys.executable, str(REPO / "bin/infinity-theme"), "apply", "signal-archive", "--target-root", str(root), "--target-user", "testuser"],
            cwd=REPO,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode != 0:
            raise SystemExit(result.stdout + result.stderr)
        generated = root / "home/testuser/.config/hypr/generated-theme.lua"
        old = root / "home/testuser/.config/hypr/generated-theme.conf"
        if not generated.is_file() or old.exists():
            raise SystemExit("Hyprland theme output did not switch from .conf to .lua")
        content = generated.read_text(encoding="utf-8")
        for expected in ["hl.config({", "active_border", "inactive_border", "rgba(", "rounding", "blur"]:
            if expected not in content:
                raise SystemExit(f"Hyprland Lua theme output omitted {expected}")
        result = subprocess.run(
            [sys.executable, str(REPO / "bin/infinity-theme"), "apply", "aurora", "--target-root", str(root), "--target-user", "testuser"],
            cwd=REPO,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode != 0:
            raise SystemExit(result.stdout + result.stderr)
        if (root / "home/testuser/.local/share/infinity-os/current-theme").read_text(encoding="utf-8") != "aurora\n":
            raise SystemExit("theme rerun did not replace the selected theme state")

    with tempfile.TemporaryDirectory(prefix="infinity-theme-rollback-") as tmp:
        root = Path(tmp)
        passwd = root / "etc/passwd"
        passwd.parent.mkdir()
        passwd.write_text(
            f"testuser:x:{os.geteuid()}:{os.getegid()}:Test User:/home/testuser:/bin/bash\n",
            encoding="utf-8",
        )
        home = root / "home/testuser"
        existing = home / ".config/infinity-os/theme.json"
        existing.parent.mkdir(parents=True)
        existing.write_text("previous\n", encoding="utf-8")
        result = run_theme_with_fault(root)
        if result.returncode == 0:
            raise SystemExit("fault-injected theme apply unexpectedly succeeded")
        if "test fault after 1 theme updates" not in result.stderr:
            raise SystemExit(f"theme apply failed before fault injection:\n{result.stderr}")
        if existing.read_text(encoding="utf-8") != "previous\n":
            raise SystemExit("existing theme file was not restored")
        created = home / ".config/quickshell/generated/theme.json"
        if created.exists():
            raise SystemExit("new file remained after rollback")

    with tempfile.TemporaryDirectory(prefix="infinity-theme-permissions-") as tmp:
        root = Path(tmp)
        passwd = root / "etc/passwd"
        passwd.parent.mkdir()
        passwd.write_text(
            f"testuser:x:{os.geteuid()}:{os.getegid()}:Test User:/home/testuser:/bin/bash\n",
            encoding="utf-8",
        )
        blocked_parent = root / "home/testuser/.config/quickshell"
        blocked_parent.mkdir(parents=True)
        blocked_parent.chmod(0o555)
        try:
            result = subprocess.run(
                [
                    sys.executable,
                    str(REPO / "bin/infinity-theme"),
                    "apply",
                    "aurora",
                    "--target-root",
                    str(root),
                    "--target-user",
                    "testuser",
                ],
                cwd=REPO,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        finally:
            blocked_parent.chmod(0o755)
        if result.returncode == 0:
            raise SystemExit("theme apply unexpectedly accepted an unwritable generated parent")
        blocked_destination = blocked_parent / "generated"
        if str(blocked_destination) not in result.stderr:
            raise SystemExit(f"theme permission error omitted blocked parent {blocked_destination}:\n{result.stderr}")
        if "ownership and write/execute permissions" not in result.stderr:
            raise SystemExit(f"theme permission error omitted recovery guidance:\n{result.stderr}")
    print("ok: theme rollback fault injection")

if __name__ == "__main__":
    main()
