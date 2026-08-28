#!/usr/bin/env python3
import os
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix="infinity-pacman-command-") as tmp:
        scratch = Path(tmp)
        fake_bin = scratch / "bin"
        fake_bin.mkdir()
        argv_file = scratch / "argv.txt"
        pacman = fake_bin / "pacman"
        pacman.write_text(
            "#!/usr/bin/env bash\nprintf '%s\\n' \"$@\" > \"$PACMAN_ARGV\"\n",
            encoding="utf-8",
        )
        pacman.chmod(0o755)
        script = "source installation/lib/installer.sh; INFINITY_REPO=$PWD; infinity_install_preview_packages"
        result = subprocess.run(
            ["bash", "-c", script],
            cwd=REPO,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=os.environ | {"PATH": f"{fake_bin}:{os.environ['PATH']}", "PACMAN_ARGV": str(argv_file)},
        )
        if result.returncode != 0:
            raise SystemExit(result.stdout + result.stderr)
        args = argv_file.read_text(encoding="utf-8").splitlines()
        expected_prefix = ["-Syu", "--needed", "--noconfirm"]
        if args[:3] != expected_prefix:
            raise SystemExit(f"bad pacman prefix: {args[:3]}")
        for package in ["hyprland", "quickshell", "ghostty", "noto-fonts"]:
            if package not in args[3:]:
                raise SystemExit(f"pacman command omitted {package}")
    print("ok: preview pacman command construction")


if __name__ == "__main__":
    main()
