#!/usr/bin/python3
from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

OFFICIAL_GROUPS = ("base", "hardware", "wayland", "desktop-shell", "applications")
EXCLUDED_MICROCODES = frozenset(("amd-ucode", "intel-ucode"))
PACKAGE_TOKEN = re.compile(r"^[a-z0-9][a-z0-9@._+-]*$")


class PackageSelectionError(ValueError):
    pass


@dataclass(frozen=True)
class MicrocodeDecision:
    package: str | None
    reason: str


def parse_manifest(text: str, source: str) -> list[str]:
    packages: list[str] = []
    for line_no, line in enumerate(text.splitlines(), 1):
        item = line.split("#", 1)[0].strip()
        if not item:
            continue
        if PACKAGE_TOKEN.fullmatch(item) is None:
            raise PackageSelectionError(f"invalid package token at {source}:{line_no}: {item!r}")
        packages.append(item)
    return packages


def package_groups_dir(repo: Path) -> Path:
    return repo / "system" / "packages"


def read_official_group_manifests(repo: Path) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    root = package_groups_dir(repo)
    for group in OFFICIAL_GROUPS:
        path = root / f"{group}.official.txt"
        groups[group] = parse_manifest(path.read_text(encoding="utf-8"), str(path))
    return groups


def choose_microcode(is_virtual: bool, cpuinfo: str) -> MicrocodeDecision:
    if is_virtual:
        return MicrocodeDecision(None, "virtualized/container host detected; guest microcode is skipped")
    if "GenuineIntel" in cpuinfo:
        return MicrocodeDecision("intel-ucode", "bare-metal GenuineIntel CPU detected")
    if "AuthenticAMD" in cpuinfo:
        return MicrocodeDecision("amd-ucode", "bare-metal AuthenticAMD CPU detected")
    raise PackageSelectionError("bare-metal CPU vendor is unknown; expected GenuineIntel or AuthenticAMD in /proc/cpuinfo")


def select_packages(groups: dict[str, list[str]], microcode: MicrocodeDecision) -> list[str]:
    selected: list[str] = []
    seen: set[str] = set()
    for group in OFFICIAL_GROUPS:
        if group not in groups:
            raise PackageSelectionError(f"missing package group {group!r}")
        for package in groups[group]:
            if package in EXCLUDED_MICROCODES:
                continue
            if package not in seen:
                selected.append(package)
                seen.add(package)
    if microcode.package is not None and microcode.package not in seen:
        selected.append(microcode.package)
    if not selected:
        raise PackageSelectionError("package selection is empty")
    return selected


def pacman_argv(packages: list[str]) -> list[str]:
    if not packages:
        raise PackageSelectionError("refusing to build an empty pacman command")
    return ["/usr/bin/pacman", "-Syu", "--needed", "--noconfirm", "--", *packages]


def printable_argv(argv: list[str]) -> str:
    return " ".join(argv)


def detect_virtual(systemd_detect_virt: str = "/usr/bin/systemd-detect-virt") -> bool:
    result = subprocess.run([systemd_detect_virt, "--quiet"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode == 0:
        return True
    if result.returncode == 1:
        return False
    raise PackageSelectionError(f"systemd-detect-virt failed with exit status {result.returncode}")


def read_cpuinfo(path: Path = Path("/proc/cpuinfo")) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def production_microcode_decision() -> MicrocodeDecision:
    return choose_microcode(detect_virtual(), read_cpuinfo())


def select_repository_packages(repo: Path, microcode: MicrocodeDecision) -> list[str]:
    return select_packages(read_official_group_manifests(repo), microcode)
