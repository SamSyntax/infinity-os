#!/usr/bin/env python3
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "installation/lib"))
from safe_fs import append_regular, init_regular, resolve_root


def run(*arguments):
    return subprocess.run(arguments, cwd=REPO, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def require_failure(result, label):
    if result.returncode == 0:
        raise SystemExit(f"{label} unexpectedly succeeded")


def main():
    with tempfile.TemporaryDirectory(prefix="infinity-safe-paths-") as tmp:
        root = Path(tmp)
        passwd = root / "etc/passwd"
        passwd.parent.mkdir()
        passwd.write_text(
            f"tester:x:{os.geteuid()}:{os.getegid()}:Test User:/home/tester:/bin/bash\n",
            encoding="utf-8",
        )
        require_failure(run(str(REPO / "bin/infinity-deploy"), "--dry-run", "--target-root", str(root), "--target-user", "../../etc"), "deploy traversal")
        require_failure(run(str(REPO / "bin/infinity-theme"), "apply", "../schema", "--dry-run", "--target-root", str(root), "--target-user", "tester"), "theme traversal")

        home = root / "home/tester"
        outside = root / "outside"
        outside.mkdir()
        home.mkdir(parents=True)
        (home / ".config").symlink_to(outside, target_is_directory=True)
        result = run(str(REPO / "bin/infinity-theme"), "apply", "aurora", "--target-root", str(root), "--target-user", "tester")
        require_failure(result, "symlinked theme destination")
        if any(outside.iterdir()):
            raise SystemExit("theme write escaped through a symlink")

    with tempfile.TemporaryDirectory(prefix="infinity-safe-log-") as tmp:
        root = Path(tmp)
        resolved = resolve_root(str(root))
        outside = root / "outside"
        outside.mkdir()
        log_parent = root / "var/log"
        log_parent.parent.mkdir()
        log_parent.symlink_to(outside, target_is_directory=True)
        try:
            init_regular(resolved, root / "var/log/infinity-os/install.log")
        except ValueError:
            pass
        else:
            raise SystemExit("safe log initialization accepted a symlinked parent")

    with tempfile.TemporaryDirectory(prefix="infinity-safe-log-file-") as tmp:
        root = Path(tmp)
        resolved = resolve_root(str(root))
        outside = root / "outside.log"
        outside.write_text("outside\n", encoding="utf-8")
        log = root / "var/log/infinity-os/install.log"
        log.parent.mkdir(parents=True)
        log.symlink_to(outside)
        try:
            append_regular(resolved, log, b"escape\n")
        except ValueError:
            pass
        else:
            raise SystemExit("safe log append accepted a symlinked file")
        if outside.read_text(encoding="utf-8") != "outside\n":
            raise SystemExit("safe log append escaped through a symlink")
    print("ok: safe target paths")


if __name__ == "__main__":
    main()
