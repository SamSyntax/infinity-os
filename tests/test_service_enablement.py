#!/usr/bin/env python3
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
INSTALLER = REPO / "install.sh"
INSTALLER_LIB = REPO / "installation/lib/installer.sh"
SERVICE_STAGE = REPO / "installation/stages/services.py"
SERVICE_MANIFEST = REPO / "system/services/enabled-system-units.tsv"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_service_stage():
    spec = importlib.util.spec_from_file_location("infinity_services", SERVICE_STAGE)
    require(spec is not None and spec.loader is not None, "service stage module cannot be loaded")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def make_target(root: Path) -> None:
    vendor = root / "usr/lib/systemd/system"
    vendor.mkdir(parents=True)
    (root / "etc/systemd/system").mkdir(parents=True)
    for unit in ["NetworkManager.service", "bluetooth.service", "power-profiles-daemon.service"]:
        (vendor / unit).write_text(f"[Unit]\nDescription={unit}\n", encoding="utf-8")


def run_installer(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(INSTALLER), *arguments],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> None:
    services = load_service_stage()
    entries = services.parse_manifest(SERVICE_MANIFEST)
    require(
        [(entry.unit, entry.target, entry.package) for entry in entries]
        == [
            ("NetworkManager.service", "multi-user.target", "networkmanager"),
            ("bluetooth.service", "bluetooth.target", "bluez"),
            ("power-profiles-daemon.service", "multi-user.target", "power-profiles-daemon"),
        ],
        "service enablement manifest changed unexpectedly",
    )
    official_packages = set()
    for manifest in (REPO / "system/packages").glob("*.official.txt"):
        for raw_line in manifest.read_text(encoding="utf-8").splitlines():
            package = raw_line.split("#", 1)[0].strip()
            if package:
                official_packages.add(package)
    missing_packages = sorted(entry.package for entry in entries if entry.package not in official_packages)
    require(not missing_packages, f"enabled services lack official package providers: {missing_packages}")

    with tempfile.TemporaryDirectory(prefix="infinity-services-manifests-") as tmp:
        manifest = Path(tmp) / "units.tsv"
        for invalid in [
            "",
            "NetworkManager.service multi-user.target",
            "NetworkManager.service multi-user.target networkmanager extra",
            "../escape.service multi-user.target networkmanager",
            "NetworkManager.service ../escape.target networkmanager",
            "NetworkManager.service multi-user.target ../networkmanager",
            "NetworkManager.service multi-user.target networkmanager\nNetworkManager.service multi-user.target networkmanager",
        ]:
            manifest.write_text(invalid, encoding="utf-8")
            try:
                services.parse_manifest(manifest)
            except services.ServiceEnablementError:
                pass
            else:
                raise SystemExit(f"invalid service manifest was accepted: {invalid!r}")

    with tempfile.TemporaryDirectory(prefix="infinity-services-plan-") as tmp:
        root = Path(tmp)
        plan = run_installer("--plan", "--target-root", str(root), "--target-user", "tester", "--stage", "services")
        require(plan.returncode == 0, plan.stdout + plan.stderr)
        for expected in [
            "NetworkManager.service -> multi-user.target",
            "bluetooth.service -> bluetooth.target",
            "power-profiles-daemon.service -> multi-user.target",
            "greetd, sshd, portals, UPower, PipeWire, WirePlumber, and hypridle remain deferred",
        ]:
            require(expected in plan.stdout, f"services plan omitted {expected!r}")
        require(not any(root.iterdir()), "services plan wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-services-apply-") as tmp:
        root = Path(tmp)
        make_target(root)
        first = services.apply(root, entries)
        require([result.status for result in first] == ["created", "created", "created"], "first services apply did not create every link")
        expected_links = {
            root / "etc/systemd/system/multi-user.target.wants/NetworkManager.service": "/usr/lib/systemd/system/NetworkManager.service",
            root / "etc/systemd/system/bluetooth.target.wants/bluetooth.service": "/usr/lib/systemd/system/bluetooth.service",
            root / "etc/systemd/system/multi-user.target.wants/power-profiles-daemon.service": "/usr/lib/systemd/system/power-profiles-daemon.service",
        }
        for destination, target in expected_links.items():
            require(destination.is_symlink() and os.readlink(destination) == target, f"wrong enablement link: {destination}")
        second = services.apply(root, entries)
        require([result.status for result in second] == ["existing", "existing", "existing"], "services rerun was not idempotent")

    with tempfile.TemporaryDirectory(prefix="infinity-services-missing-") as tmp:
        root = Path(tmp)
        make_target(root)
        (root / "usr/lib/systemd/system/bluetooth.service").unlink()
        try:
            services.apply(root, entries)
        except services.ServiceEnablementError as error:
            require("bluetooth.service" in str(error), "missing-unit error did not name the unit")
        else:
            raise SystemExit("services apply accepted a missing unit")
        require(not list((root / "etc/systemd/system").glob("*.wants/*")), "missing-unit validation left partial links")

    with tempfile.TemporaryDirectory(prefix="infinity-services-escape-") as tmp:
        root = Path(tmp) / "root"
        outside = Path(tmp) / "outside"
        root.mkdir()
        outside.mkdir()
        make_target(root)
        (root / "etc/systemd/system/multi-user.target.wants").symlink_to(outside, target_is_directory=True)
        try:
            services.apply(root, entries)
        except (OSError, ValueError, services.ServiceEnablementError):
            pass
        else:
            raise SystemExit("services apply accepted a symlinked wants directory")
        require(not any(outside.iterdir()), "services apply escaped through a symlinked wants directory")

    with tempfile.TemporaryDirectory(prefix="infinity-services-conflict-") as tmp:
        root = Path(tmp)
        make_target(root)
        wants = root / "etc/systemd/system/multi-user.target.wants"
        wants.mkdir()
        conflict = wants / "NetworkManager.service"
        conflict.symlink_to("/usr/lib/systemd/system/wrong.service")
        try:
            services.apply(root, entries)
        except services.ServiceEnablementError as error:
            require("conflicting" in str(error), "wrong-link error was not actionable")
        else:
            raise SystemExit("services apply replaced a conflicting link")
        require(os.readlink(conflict) == "/usr/lib/systemd/system/wrong.service", "conflicting link was modified")

    with tempfile.TemporaryDirectory(prefix="infinity-services-file-conflict-") as tmp:
        root = Path(tmp)
        make_target(root)
        wants = root / "etc/systemd/system/multi-user.target.wants"
        wants.mkdir()
        conflict = wants / "power-profiles-daemon.service"
        conflict.write_text("preserve\n", encoding="utf-8")
        try:
            services.apply(root, entries)
        except services.ServiceEnablementError:
            pass
        else:
            raise SystemExit("services apply replaced an ordinary-file conflict")
        require(conflict.read_text(encoding="utf-8") == "preserve\n", "ordinary-file conflict was modified")
        require(not (wants / "NetworkManager.service").exists(), "late conflict left an earlier service link")

    with tempfile.TemporaryDirectory(prefix="infinity-services-source-link-") as tmp:
        root = Path(tmp)
        make_target(root)
        source = root / "usr/lib/systemd/system/bluetooth.service"
        source.unlink()
        source.symlink_to("NetworkManager.service")
        try:
            services.validate(root, entries)
        except (OSError, ValueError, services.ServiceEnablementError):
            pass
        else:
            raise SystemExit("services validation accepted a symlinked source unit")

    live_root = run_installer("--confirm", "--target-root", "/", "--target-user", "tester", "--stage", "services")
    require(live_root.returncode != 0 and "offline target" in live_root.stderr, "services apply accepted the live root")
    try:
        services.validate(Path("/"), entries)
    except services.ServiceEnablementError as error:
        require("offline target" in str(error), "service module live-root error was unclear")
    else:
        raise SystemExit("service module accepted the live root directly")

    with tempfile.TemporaryDirectory(prefix="infinity-services-active-") as tmp:
        root = Path(tmp)
        (root / "run/systemd/system").mkdir(parents=True)
        active = run_installer("--confirm", "--target-root", str(root), "--target-user", "tester", "--stage", "services")
        require(active.returncode != 0 and "appears active" in active.stderr, "services apply accepted an active target marker")
        require(not (root / "var/log/infinity-os/install.log").exists(), "active-target rejection created an installer log")
        try:
            services.validate(root, entries)
        except services.ServiceEnablementError as error:
            require("appears active" in str(error), "service module active-target error was unclear")
        else:
            raise SystemExit("service module accepted an active target marker directly")

    with tempfile.TemporaryDirectory(prefix="infinity-services-combo-") as tmp:
        combined = run_installer(
            "--confirm", "--target-root", tmp, "--target-user", "tester", "--stage", "services", "--stage", "preflight"
        )
        require(combined.returncode != 0 and "services apply must be selected by itself" in combined.stderr, "services combination was accepted")
        require(not any(Path(tmp).iterdir()), "rejected services combination wrote into the target root")

    with tempfile.TemporaryDirectory(prefix="infinity-services-elevation-") as tmp:
        elevation_script = "\n".join(
            [
                'source "$1"',
                "infinity_effective_uid() { printf '1000\\n'; }",
                "infinity_services_preflight() { printf 'PREFLIGHT\\n'; }",
                "infinity_exec_sudo() {",
                "  printf 'SUDO\\n'",
                "  printf '%s\\n' \"$@\"",
                "  return 73",
                "}",
                "infinity_prewrite_services_validation() { printf 'PRIVILEGED-WORK-REACHED\\n'; return 99; }",
                'infinity_installer_main --confirm --target-root "$2" --target-user tester --stage services',
            ]
        )
        elevation = subprocess.run(
            ["/usr/bin/bash", "-c", elevation_script, "bash", str(INSTALLER_LIB), tmp],
            cwd=REPO,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        require(elevation.returncode == 73, elevation.stdout + elevation.stderr)
        require(
            elevation.stdout.splitlines()
            == [
                "PREFLIGHT",
                "SUDO",
                str(INSTALLER),
                "--confirm",
                "--target-root",
                tmp,
                "--target-user",
                "tester",
                "--stage",
                "services",
            ],
            f"services elevation did not preserve canonical arguments:\n{elevation.stdout}",
        )
        require("PRIVILEGED-WORK-REACHED" not in elevation.stdout, "services continued into privileged work after sudo request")

    source = INSTALLER_LIB.read_text(encoding="utf-8") + "\n" + SERVICE_STAGE.read_text(encoding="utf-8")
    for forbidden in ["systemctl", "--now", " start ", " restart "]:
        require(forbidden not in source, f"services implementation contains forbidden process-control token {forbidden!r}")

    print("ok: offline services plan, validation, enablement, idempotency, and host isolation")


if __name__ == "__main__":
    main()
