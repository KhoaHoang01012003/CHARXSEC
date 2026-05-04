from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path


RUN_ID_PATTERN = re.compile(r"""^\s*RUN_ID=(?P<quote>['"]?)(?P<run_id>[^'"\n]+)(?P=quote)\s*$""")
FALLBACK_WARNING = "No active runtime rootfs_rw found; using lab rootfs_ro."


@dataclass(frozen=True)
class RuntimeSelection:
    rootfs: Path
    lab_dir: Path
    runtime: str
    source: str
    run_id: str = ""
    warnings: tuple[str, ...] = ()

    def warning_list(self) -> list[str]:
        return list(self.warnings)

    def metadata(self) -> dict[str, object]:
        return {
            "rootfs": str(self.rootfs),
            "lab_dir": str(self.lab_dir),
            "runtime": self.runtime,
            "source": self.source,
            "runtime_run_id": self.run_id,
            "warnings": self.warning_list(),
        }


def default_lab_dir() -> Path:
    configured = os.environ.get("CHARX_LAB_DIR") or os.environ.get("CHARX_LAB_HOME")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / "charx_labs" / "charx_v190"


def parse_run_id_from_state(path: Path) -> str:
    if not path.exists():
        return ""
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    for line in lines:
        match = RUN_ID_PATTERN.match(line)
        if match:
            return match.group("run_id").strip()
    return ""


def read_last_run_id(path: Path | None) -> str:
    if path is None or not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""


def rootfs_rw_for(lab_dir: Path, run_id: str) -> Path:
    return lab_dir / "runs" / run_id / "rootfs_rw"


def require_dir(path: Path, message: str) -> Path:
    resolved = path.expanduser().resolve()
    if not resolved.is_dir():
        raise SystemExit(f"{message}: {resolved}")
    return resolved


def resolve_runtime_rootfs(
    *,
    rootfs: Path | None,
    lab_dir: Path | None,
    runtime: str,
    runtime_run_id: str | None,
    last_run_file: Path | None = Path("/tmp/charx-full-last-run-id"),
) -> RuntimeSelection:
    resolved_lab = (lab_dir or default_lab_dir()).expanduser().resolve()
    runtime = runtime.strip().lower()

    if rootfs is not None:
        return RuntimeSelection(
            rootfs=require_dir(rootfs, "rootfs must be an existing directory"),
            lab_dir=resolved_lab,
            runtime=runtime,
            source="manual-rootfs",
        )

    rootfs_ro = resolved_lab / "rootfs_ro"
    if runtime == "ro":
        return RuntimeSelection(
            rootfs=require_dir(rootfs_ro, "lab rootfs_ro must be an existing directory"),
            lab_dir=resolved_lab,
            runtime=runtime,
            source="rootfs-ro",
        )

    if runtime != "active":
        raise SystemExit(f"unknown runtime mode: {runtime}")

    candidate_run_id = (runtime_run_id or "").strip()
    if not candidate_run_id:
        candidate_run_id = parse_run_id_from_state(resolved_lab / "state" / "wbm_session.env")
    if not candidate_run_id:
        candidate_run_id = read_last_run_id(last_run_file)

    if candidate_run_id:
        rootfs_rw = rootfs_rw_for(resolved_lab, candidate_run_id)
        if rootfs_rw.is_dir():
            return RuntimeSelection(
                rootfs=rootfs_rw.resolve(),
                lab_dir=resolved_lab,
                runtime=runtime,
                source="active-rootfs-rw",
                run_id=candidate_run_id,
            )

    if rootfs_ro.is_dir():
        return RuntimeSelection(
            rootfs=rootfs_ro.resolve(),
            lab_dir=resolved_lab,
            runtime=runtime,
            source="fallback-rootfs-ro",
            run_id=candidate_run_id,
            warnings=(FALLBACK_WARNING,),
        )

    raise SystemExit(
        f"no runtime rootfs found: expected active rootfs_rw or fallback rootfs_ro under {resolved_lab}"
    )
