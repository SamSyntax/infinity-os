#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def execute(root):
    result = subprocess.run(
        [str(REPO / "bin/infinity-deploy"), "--target-root", str(root), "--target-user", "tester"],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)


def main():
    with tempfile.TemporaryDirectory(prefix="infinity-deployment-") as tmp:
        root = Path(tmp)
        execute(root)
        home = root / "home/tester"
        config = home / ".config/hypr/hyprland.lua"
        config.write_text("user conflict\n", encoding="utf-8")
        execute(root)

        backup_root = home / ".local/share/infinity-os/backups"
        backups = [path for path in backup_root.rglob("hyprland.lua") if path.is_file()]
        if len(backups) != 1 or backups[0].read_text(encoding="utf-8") != "user conflict\n":
            raise SystemExit("rerun did not preserve the conflicting target config")
        manifest = json.loads((home / ".local/share/infinity-os/deployment-manifest.json").read_text(encoding="utf-8"))
        if not manifest["files"]:
            raise SystemExit("deployment manifest contains no files")
        if not (root / "usr/share/infinity-os/wallpapers/nocturne.svg").is_file():
            raise SystemExit("greeter wallpaper was not deployed")
    print("ok: deployment rerun, backup, manifest, and system asset")


if __name__ == "__main__":
    main()
