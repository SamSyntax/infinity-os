#!/usr/bin/python3
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "installation/lib"))

from package_selection import (  # noqa: E402
    MicrocodeDecision,
    PackageSelectionError,
    choose_microcode,
    detect_virtual,
    pacman_argv,
    parse_manifest,
    read_official_group_manifests,
    select_packages,
)


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def require_raises(func, expected):
    try:
        func()
    except Exception as error:
        require(expected in str(error), f"wrong error {error!r}; expected {expected!r}")
        return
    raise SystemExit(f"expected error containing {expected!r}")


def main():
    groups = {
        "base": ["git", "curl"],
        "hardware": ["intel-ucode", "bluez", "git", "amd-ucode"],
        "wayland": ["hyprland", "bluez"],
        "desktop-shell": ["quickshell", "noto-fonts"],
        "applications": ["firefox", "ghostty", "curl"],
    }
    selected = select_packages(groups, MicrocodeDecision("intel-ucode", "test Intel"))
    require(
        selected == ["git", "curl", "bluez", "hyprland", "quickshell", "noto-fonts", "firefox", "ghostty", "intel-ucode"],
        f"bad group merge/order/dedup/microcode filtering: {selected}",
    )

    require(choose_microcode(True, "vendor_id: GenuineIntel").package is None, "VM/container selected guest microcode")
    require(choose_microcode(False, "vendor_id\t: GenuineIntel").package == "intel-ucode", "Intel bare metal did not select intel-ucode")
    require(choose_microcode(False, "vendor_id\t: AuthenticAMD").package == "amd-ucode", "AMD bare metal did not select amd-ucode")
    require_raises(lambda: choose_microcode(False, "vendor_id\t: CentaurHauls"), "unknown")

    repository_groups = read_official_group_manifests(REPO)
    repository_selected = select_packages(repository_groups, MicrocodeDecision(None, "vm"))
    for excluded in ["mesa", "vulkan-radeon", "vulkan-intel", "nvidia-open", "nvidia-utils", "nvidia-settings"]:
        require(excluded not in repository_selected, f"graphics package was selected by packages stage: {excluded}")
    require("greetd-tuigreet" in repository_selected, "new greetd-tuigreet package missing")
    require("noto-fonts" in repository_selected, "noto-fonts missing from selected packages")
    require("tuigreet" not in repository_selected, "old tuigreet package still selected")
    require("nvidia" not in repository_selected, "old nvidia package leaked into selected packages")

    argv = pacman_argv(["git", "hyprland"])
    require(argv == ["/usr/bin/pacman", "-Syu", "--needed", "--noconfirm", "--", "git", "hyprland"], f"bad pacman argv: {argv}")
    require_raises(lambda: pacman_argv([]), "empty")
    require_raises(lambda: parse_manifest("--dbonly\n", "test"), "invalid package token")
    require_raises(lambda: parse_manifest("git trailing\n", "test"), "invalid package token")

    with tempfile.TemporaryDirectory(prefix="infinity-detect-virt-") as tmp:
        detector = Path(tmp) / "systemd-detect-virt"
        detector.write_text("#!/usr/bin/bash\nexit 2\n", encoding="utf-8")
        detector.chmod(0o755)
        require_raises(lambda: detect_virtual(str(detector)), "exit status 2")

    print("ok: package selection order, microcode, exclusions, argv, and parser rejection")


if __name__ == "__main__":
    main()
