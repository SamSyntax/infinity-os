#!/usr/bin/python3
import json
import os
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DEPLOY = REPO / "bin/infinity-deploy"


def run(root, *extra):
    return subprocess.run(
        [str(DEPLOY), "--target-root", str(root), "--target-user", "tester", *extra],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def add_passwd(root):
    passwd = root / "etc/passwd"
    passwd.parent.mkdir()
    passwd.write_text(f"tester:x:{os.geteuid()}:{os.getegid()}:Test User:/home/tester:/bin/bash\n", encoding="utf-8")


def main():
    with tempfile.TemporaryDirectory(prefix="infinity-deploy-user-scope-") as tmp:
        root = Path(tmp)
        add_passwd(root)
        plan = run(root, "--scope", "user", "--dry-run")
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        require(".config/hypr/hyprland.lua" in plan.stdout, "user scope dry-run omitted user config")
        require("etc/greetd" not in plan.stdout, "user scope dry-run included greetd")
        require("usr/share/infinity-os/wallpapers" not in plan.stdout, "user scope dry-run included shared wallpaper")

        apply = run(root, "--scope", "user")
        require(apply.returncode == 0, apply.stdout + apply.stderr)
        home = root / "home/tester"
        require((home / ".config/hypr/hyprland.lua").is_file(), "user scope did not deploy Hyprland config")
        require((home / ".local/share/infinity-os/deployment-manifest.json").is_file(), "user scope did not write manifest")
        require(not (root / "etc/greetd/config.toml").exists(), "user scope wrote greetd config")
        require(not (root / "usr/share/infinity-os/wallpapers/nocturne.svg").exists(), "user scope wrote shared wallpaper")
        manifest = json.loads((home / ".local/share/infinity-os/deployment-manifest.json").read_text(encoding="utf-8"))
        require(all("/etc/" not in item["target"] and "/usr/share/" not in item["target"] for item in manifest["files"]), "manifest contains system target")
    print("ok: user-scoped deployment excludes system targets")


if __name__ == "__main__":
    main()
