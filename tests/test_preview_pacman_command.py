#!/usr/bin/python3
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def main():
    script = "source installation/lib/installer.sh; INFINITY_REPO=$PWD; infinity_preview_pacman_argv"
    result = subprocess.run(
        ["/usr/bin/bash", "-c", script],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise SystemExit(result.stdout + result.stderr)
    args = result.stdout.splitlines()
    expected_prefix = ["/usr/bin/pacman", "-Syu", "--needed", "--noconfirm", "--"]
    if args[:5] != expected_prefix:
        raise SystemExit(f"bad pacman argv prefix: {args[:5]}")
    for package in ["hyprland", "quickshell", "ghostty", "noto-fonts", "fuzzel"]:
        if package not in args[5:]:
            raise SystemExit(f"pacman argv omitted {package}")
    if "walker" in args[5:]:
        raise SystemExit("pacman argv still includes unavailable walker package")

    with tempfile.TemporaryDirectory(prefix="infinity-pacman-parser-") as tmp:
        bad = Path(tmp) / "bad-packages.txt"
        for token in ["--dbonly", "--config"]:
            bad.write_text(f"{token}\n", encoding="utf-8")
            result = subprocess.run(
                ["/usr/bin/bash", "-c", "source installation/lib/installer.sh; INFINITY_REPO=$PWD; infinity_preview_pacman_argv \"$1\"", "bash", str(bad)],
                cwd=REPO,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if result.returncode == 0 or "invalid preview package token" not in result.stderr:
                raise SystemExit(f"option-shaped token was accepted: {token}")
            install_result = subprocess.run(
                ["/usr/bin/bash", "-c", "source installation/lib/installer.sh; INFINITY_REPO=$PWD; infinity_install_preview_packages \"$1\"", "bash", str(bad)],
                cwd=REPO,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if install_result.returncode == 0 or "invalid preview package token" not in install_result.stderr:
                raise SystemExit(f"package installation swallowed parser failure: {token}")

        fake_bin = Path(tmp) / "bin"
        fake_bin.mkdir()
        (fake_bin / "pacman").write_text("#!/usr/bin/bash\nexit 99\n", encoding="utf-8")
        (fake_bin / "pacman").chmod(0o755)
        result = subprocess.run(
            ["/usr/bin/bash", "-c", script],
            cwd=REPO,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={"PATH": f"{fake_bin}:/usr/bin:/bin"},
        )
        if result.returncode != 0 or result.stdout.splitlines()[0] != "/usr/bin/pacman":
            raise SystemExit("preview pacman argv selected PATH pacman")
    print("ok: preview pacman argv construction and parser rejection")


if __name__ == "__main__":
    main()
