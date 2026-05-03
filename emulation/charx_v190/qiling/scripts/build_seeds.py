#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_ROOTFS = Path("/home/khoa/charx_labs/charx_v190/rootfs_ro")
DEFAULT_QEMU_LAB = Path("/home/khoa/charx_labs/charx_v190")


SAFE_ROOTFS_SEEDS = [
    "/etc/charx/routePermissions.json",
    "/etc/charx/charx-website.conf",
    "/etc/charx/charx-system-config-manager.conf",
    "/etc/charx/charx-jupicore.conf",
    "/etc/charx/charx-ocpp16-agent.conf",
    "/etc/charx/charx-modbus-agent.conf",
    "/etc/charx/charx-modbus-server.conf",
    "/etc/charx/charx-loadmanagement-agent.conf",
    "/etc/charx/charx-loadmanagement-load-circuite.conf",
]


SAMPLE_JSON_SEEDS = {
    "login_user_default.json": {"username": "user", "password": "user", "role": ""},
    "login_operator_default.json": {"username": "operator", "password": "operator", "role": ""},
    "login_manufacturer_default.json": {"username": "manufacturer", "password": "manufacturer", "role": ""},
    "empty_object.json": {},
    "empty_array.json": [],
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def copy_seed(src: Path, dst: Path, provenance: str, manifest: list[dict]) -> None:
    if not src.exists():
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    manifest.append(
        {
            "name": dst.name,
            "path": str(dst),
            "source": str(src),
            "provenance": provenance,
            "sha256": sha256(dst),
            "size": dst.stat().st_size,
            "behavior_claim_allowed": False,
        }
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build safe seed corpus for CHARX Qiling harnesses.")
    parser.add_argument("--rootfs", type=Path, default=DEFAULT_ROOTFS)
    parser.add_argument("--qemu-lab", type=Path, default=DEFAULT_QEMU_LAB)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--include-evidence", action="store_true")
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    manifest: list[dict] = []

    for guest_path in SAFE_ROOTFS_SEEDS:
        src = args.rootfs / guest_path.lstrip("/")
        dst = args.out / "rootfs" / guest_path.lstrip("/").replace("/", "__")
        copy_seed(src, dst, "observed_from_artifact", manifest)

    sample_dir = args.out / "samples"
    sample_dir.mkdir(parents=True, exist_ok=True)
    for name, payload in SAMPLE_JSON_SEEDS.items():
        dst = sample_dir / name
        dst.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        manifest.append(
            {
                "name": name,
                "path": str(dst),
                "source": "generated_safe_sample",
                "provenance": "manual_test_stub",
                "sha256": sha256(dst),
                "size": dst.stat().st_size,
                "behavior_claim_allowed": False,
            }
        )

    if args.include_evidence:
        probes = sorted((args.qemu_lab / "evidence").glob("*/probes/*.json"))
        for src in probes[-20:]:
            dst = args.out / "qemu_evidence" / src.name
            copy_seed(src, dst, "observed_runtime_qemu", manifest)

    manifest_doc = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "rootfs": str(args.rootfs),
        "qemu_lab": str(args.qemu_lab),
        "notes": "Seeds are for harnessing only. They are not device behavior truth.",
        "seeds": manifest,
    }
    (args.out / "seed_manifest.json").write_text(
        json.dumps(manifest_doc, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(args.out / "seed_manifest.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
