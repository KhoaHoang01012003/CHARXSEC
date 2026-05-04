# Runtime-Active Code Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `code-browser` default to the active emulation runtime rootfs (`rootfs_rw`) when available, and fall back to lab `rootfs_ro` with an explicit warning when no active run exists.

**Architecture:** Keep firmware browser engines product-neutral and add a small runtime resolver layer at the CLI boundary. `--rootfs` remains a manual override; when omitted, `--runtime active` resolves the CHARX-style lab directory, active run id, and rootfs path before creating `BrowserContext`.

**Tech Stack:** Python 3.11, argparse, pytest, PowerShell/WSL launchers, existing `firmware_browser` package.

---

## File Structure

- `emulation/charx_v190/pentest/firmware_browser/runtime.py`: new lab/runtime path resolver. It knows how to find `rootfs_rw` for active/latest runs and `rootfs_ro` fallback. It must not scan files.
- `emulation/charx_v190/pentest/firmware_browser/models.py`: extend `BrowserContext` with runtime metadata used in output artifacts.
- `emulation/charx_v190/pentest/firmware_browser/cli.py`: make `--rootfs` optional, add `--runtime active`, `--lab-dir`, and `--run-id`, print fallback warnings to stderr.
- `emulation/charx_v190/pentest/firmware_browser/orchestrator.py`: include runtime metadata in `inventory.json`.
- `emulation/charx_v190/pentest/firmware_browser/skill_context.py`: include runtime metadata in `skill_context.json`.
- `emulation/charx_v190/pentest/tests/test_firmware_browser_runtime.py`: unit tests for active run resolution and fallback warning.
- `emulation/charx_v190/pentest/tests/test_firmware_browser_cli.py`: CLI tests for rootfs override and runtime default.
- `emulation/charx_v190/pentest/tests/test_firmware_browser_orchestrator.py`: metadata output test.
- `document/charx_sec_3100_local_pentest_workstation_guide_vi.md`: update examples to use runtime default first.
- `emulation/charx_v190/pentest/README.md`: document runtime-aware defaults.

---

### Task 1: Runtime Resolver

**Files:**
- Create: `emulation/charx_v190/pentest/firmware_browser/runtime.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_runtime.py`

- [ ] **Step 1: Write failing runtime resolver tests**

Create `emulation/charx_v190/pentest/tests/test_firmware_browser_runtime.py`:

```python
from pathlib import Path

from firmware_browser.runtime import resolve_runtime_rootfs


def test_active_runtime_uses_session_rootfs_rw(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    active = lab / "runs" / "run-1" / "rootfs_rw"
    active.mkdir(parents=True)
    (lab / "state").mkdir()
    (lab / "state" / "wbm_session.env").write_text('RUN_ID="run-1"\n', encoding="utf-8")
    (lab / "rootfs_ro").mkdir()

    selection = resolve_runtime_rootfs(lab_dir=lab, runtime="active", run_id=None, last_run_file=None)

    assert selection.rootfs == active.resolve()
    assert selection.source == "active-rootfs-rw"
    assert selection.run_id == "run-1"
    assert selection.warnings == []


def test_active_runtime_falls_back_to_rootfs_ro_with_warning(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    rootfs_ro = lab / "rootfs_ro"
    rootfs_ro.mkdir(parents=True)

    selection = resolve_runtime_rootfs(lab_dir=lab, runtime="active", run_id=None, last_run_file=None)

    assert selection.rootfs == rootfs_ro.resolve()
    assert selection.source == "fallback-rootfs-ro"
    assert selection.run_id == ""
    assert selection.warnings == ["No active runtime rootfs_rw found; using lab rootfs_ro."]


def test_explicit_run_id_uses_matching_rootfs_rw(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    selected = lab / "runs" / "run-2" / "rootfs_rw"
    selected.mkdir(parents=True)
    (lab / "rootfs_ro").mkdir()

    selection = resolve_runtime_rootfs(lab_dir=lab, runtime="active", run_id="run-2", last_run_file=None)

    assert selection.rootfs == selected.resolve()
    assert selection.run_id == "run-2"
    assert selection.source == "active-rootfs-rw"


def test_runtime_ro_uses_rootfs_ro(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    rootfs_ro = lab / "rootfs_ro"
    rootfs_ro.mkdir(parents=True)

    selection = resolve_runtime_rootfs(lab_dir=lab, runtime="ro", run_id=None, last_run_file=None)

    assert selection.rootfs == rootfs_ro.resolve()
    assert selection.source == "rootfs-ro"
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_runtime.py -q
```

Expected: fail with `ModuleNotFoundError: No module named 'firmware_browser.runtime'`.

- [ ] **Step 3: Implement runtime resolver**

Create `emulation/charx_v190/pentest/firmware_browser/runtime.py`:

```python
from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path


RUN_ID_PATTERN = re.compile(r"""^\s*RUN_ID=(?P<quote>['"]?)(?P<run_id>[^'"\n]+)(?P=quote)\s*$""")


@dataclass(frozen=True)
class RuntimeSelection:
    rootfs: Path
    lab_dir: Path
    runtime: str
    source: str
    run_id: str = ""
    warnings: list[str] | None = None

    def warning_list(self) -> list[str]:
        return list(self.warnings or [])


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


def resolve_runtime_rootfs(
    lab_dir: Path | None = None,
    runtime: str = "active",
    run_id: str | None = None,
    last_run_file: Path | None = Path("/tmp/charx-full-last-run-id"),
) -> RuntimeSelection:
    resolved_lab = (lab_dir or default_lab_dir()).expanduser().resolve()
    runtime = runtime.strip().lower()
    rootfs_ro = resolved_lab / "rootfs_ro"

    if runtime == "ro":
        if not rootfs_ro.is_dir():
            raise SystemExit(f"lab rootfs_ro must be an existing directory: {rootfs_ro}")
        return RuntimeSelection(
            rootfs=rootfs_ro.resolve(),
            lab_dir=resolved_lab,
            runtime=runtime,
            source="rootfs-ro",
            warnings=[],
        )

    if runtime != "active":
        raise SystemExit(f"unknown runtime mode: {runtime}")

    candidate_run_id = (run_id or "").strip()
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
                warnings=[],
            )

    if rootfs_ro.is_dir():
        return RuntimeSelection(
            rootfs=rootfs_ro.resolve(),
            lab_dir=resolved_lab,
            runtime=runtime,
            source="fallback-rootfs-ro",
            run_id=candidate_run_id if candidate_run_id else "",
            warnings=["No active runtime rootfs_rw found; using lab rootfs_ro."],
        )

    raise SystemExit(
        f"no runtime rootfs found: expected active rootfs_rw or fallback rootfs_ro under {resolved_lab}"
    )
```

- [ ] **Step 4: Run runtime resolver tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_runtime.py -q
```

Expected: `4 passed`.

- [ ] **Step 5: Commit runtime resolver**

Run:

```bash
git add emulation/charx_v190/pentest/firmware_browser/runtime.py emulation/charx_v190/pentest/tests/test_firmware_browser_runtime.py
git commit -m "feat: resolve active firmware runtime rootfs"
```

---

### Task 2: Runtime Metadata In Browser Context

**Files:**
- Modify: `emulation/charx_v190/pentest/firmware_browser/models.py`
- Modify: `emulation/charx_v190/pentest/firmware_browser/orchestrator.py`
- Modify: `emulation/charx_v190/pentest/firmware_browser/skill_context.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_orchestrator.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_skill_context.py`

- [ ] **Step 1: Write failing metadata output tests**

Append to `emulation/charx_v190/pentest/tests/test_firmware_browser_orchestrator.py`:

```python
def test_run_scan_writes_runtime_metadata(tmp_path: Path) -> None:
    rootfs = tmp_path / "rootfs"
    rootfs.mkdir()
    context = BrowserContext(
        rootfs=rootfs,
        output_dir=tmp_path / "out",
        product_name="demo",
        runtime_source="active-rootfs-rw",
        runtime_run_id="run-1",
        runtime_lab_dir=str(tmp_path / "lab"),
        runtime_warnings=("warning text",),
    )

    assert run_scan(context, engines=["inventory"]) == 0

    payload = json.loads(context.inventory_path.read_text(encoding="utf-8"))
    assert payload["runtime"]["source"] == "active-rootfs-rw"
    assert payload["runtime"]["run_id"] == "run-1"
    assert payload["runtime"]["warnings"] == ["warning text"]
```

Append to `emulation/charx_v190/pentest/tests/test_firmware_browser_skill_context.py`:

```python
def test_skill_context_includes_runtime_metadata(tmp_path: Path) -> None:
    context = BrowserContext(
        rootfs=tmp_path / "rootfs",
        output_dir=tmp_path / "out",
        product_name="demo",
        runtime_source="fallback-rootfs-ro",
        runtime_run_id="",
        runtime_lab_dir=str(tmp_path / "lab"),
        runtime_warnings=("No active runtime rootfs_rw found; using lab rootfs_ro.",),
    )
    context.rootfs.mkdir()
    context.output_dir.mkdir()
    context.inventory_path.write_text(json.dumps({"engine_results": {}}), encoding="utf-8")

    export_skill_context(context)

    payload = json.loads(context.skill_context_path.read_text(encoding="utf-8"))
    assert payload["runtime"]["source"] == "fallback-rootfs-ro"
    assert payload["runtime"]["warnings"] == ["No active runtime rootfs_rw found; using lab rootfs_ro."]
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_orchestrator.py::test_run_scan_writes_runtime_metadata tests/test_firmware_browser_skill_context.py::test_skill_context_includes_runtime_metadata -q
```

Expected: fail with `TypeError: BrowserContext.__init__() got an unexpected keyword argument 'runtime_source'`.

- [ ] **Step 3: Extend BrowserContext**

Modify `emulation/charx_v190/pentest/firmware_browser/models.py` so `BrowserContext` becomes:

```python
@dataclass(frozen=True)
class BrowserContext:
    rootfs: Path
    output_dir: Path
    product_name: str = "generic-firmware"
    runtime_source: str = "manual-rootfs"
    runtime_run_id: str = ""
    runtime_lab_dir: str = ""
    runtime_warnings: tuple[str, ...] = ()

    @property
    def findings_path(self) -> Path:
        return self.output_dir / "findings.jsonl"

    @property
    def inventory_path(self) -> Path:
        return self.output_dir / "inventory.json"

    @property
    def skill_context_path(self) -> Path:
        return self.output_dir / "skill_context.json"

    def runtime_payload(self) -> dict[str, Any]:
        return {
            "source": self.runtime_source,
            "run_id": self.runtime_run_id,
            "lab_dir": self.runtime_lab_dir,
            "warnings": list(self.runtime_warnings),
        }
```

- [ ] **Step 4: Include runtime metadata in inventory and skill context**

Modify `emulation/charx_v190/pentest/firmware_browser/orchestrator.py` by adding `"runtime": context.runtime_payload()` to `inventory_payload`:

```python
    inventory_payload = {
        "product_name": context.product_name,
        "rootfs": str(context.rootfs),
        "runtime": context.runtime_payload(),
        "engines": selected,
        "engine_results": {},
    }
```

Modify `emulation/charx_v190/pentest/firmware_browser/skill_context.py` by adding `"runtime": context.runtime_payload()` to the payload passed to `write_json`:

```python
        {
            "product_name": context.product_name,
            "rootfs": str(context.rootfs),
            "runtime": context.runtime_payload(),
            "inventory_path": str(context.inventory_path),
            "findings_path": str(context.findings_path),
            "engine_results": inventory.get("engine_results", {}),
            "sample_findings": samples,
            "suggested_skill_use": [
                "Use binary findings for reverse-engineering triage.",
                "Use route/config findings to choose authorized runtime probes.",
                "Use CodeQL/Semgrep findings only for supported source/script/config files.",
                "Do not convert static findings into verified firmware behavior without reproduction.",
            ],
        },
```

- [ ] **Step 5: Run metadata tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_orchestrator.py tests/test_firmware_browser_skill_context.py -q
```

Expected: all tests in both files pass.

- [ ] **Step 6: Commit metadata changes**

Run:

```bash
git add emulation/charx_v190/pentest/firmware_browser/models.py emulation/charx_v190/pentest/firmware_browser/orchestrator.py emulation/charx_v190/pentest/firmware_browser/skill_context.py emulation/charx_v190/pentest/tests/test_firmware_browser_orchestrator.py emulation/charx_v190/pentest/tests/test_firmware_browser_skill_context.py
git commit -m "feat: record firmware browser runtime metadata"
```

---

### Task 3: Runtime-Aware CLI Defaults

**Files:**
- Modify: `emulation/charx_v190/pentest/firmware_browser/cli.py`
- Test: `emulation/charx_v190/pentest/tests/test_firmware_browser_cli.py`

- [ ] **Step 1: Write failing CLI tests**

Append to `emulation/charx_v190/pentest/tests/test_firmware_browser_cli.py`:

```python
def test_inventory_defaults_to_active_runtime_rootfs(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    rootfs_rw = lab / "runs" / "run-1" / "rootfs_rw"
    rootfs_rw.mkdir(parents=True)
    (rootfs_rw / "etc").mkdir()
    (rootfs_rw / "etc" / "app.conf").write_text("Port=5000\n", encoding="utf-8")
    (lab / "state").mkdir()
    (lab / "state" / "wbm_session.env").write_text("RUN_ID=run-1\n", encoding="utf-8")
    out = tmp_path / "out"

    assert main(["inventory", "--lab-dir", str(lab), "--output-dir", str(out), "--product-name", "demo"]) == 0

    payload = json.loads((out / "inventory.json").read_text(encoding="utf-8"))
    assert payload["rootfs"] == str(rootfs_rw.resolve())
    assert payload["runtime"]["source"] == "active-rootfs-rw"
    assert payload["runtime"]["run_id"] == "run-1"


def test_inventory_falls_back_to_rootfs_ro_and_warns(tmp_path: Path, capsys) -> None:
    lab = tmp_path / "lab"
    rootfs_ro = lab / "rootfs_ro"
    rootfs_ro.mkdir(parents=True)
    out = tmp_path / "out"

    assert main(["inventory", "--lab-dir", str(lab), "--output-dir", str(out), "--product-name", "demo"]) == 0

    captured = capsys.readouterr()
    payload = json.loads((out / "inventory.json").read_text(encoding="utf-8"))
    assert payload["rootfs"] == str(rootfs_ro.resolve())
    assert payload["runtime"]["source"] == "fallback-rootfs-ro"
    assert "No active runtime rootfs_rw found; using lab rootfs_ro." in captured.err


def test_rootfs_argument_overrides_runtime_resolution(tmp_path: Path) -> None:
    manual_rootfs = tmp_path / "manual-rootfs"
    manual_rootfs.mkdir()
    lab = tmp_path / "lab"
    (lab / "rootfs_ro").mkdir(parents=True)
    out = tmp_path / "out"

    assert main(["inventory", "--rootfs", str(manual_rootfs), "--lab-dir", str(lab), "--output-dir", str(out)]) == 0

    payload = json.loads((out / "inventory.json").read_text(encoding="utf-8"))
    assert payload["rootfs"] == str(manual_rootfs.resolve())
    assert payload["runtime"]["source"] == "manual-rootfs"
```

- [ ] **Step 2: Run CLI tests to verify failure**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_cli.py::test_inventory_defaults_to_active_runtime_rootfs tests/test_firmware_browser_cli.py::test_inventory_falls_back_to_rootfs_ro_and_warns tests/test_firmware_browser_cli.py::test_rootfs_argument_overrides_runtime_resolution -q
```

Expected: fail because `--rootfs` is still required or `--lab-dir` is unknown.

- [ ] **Step 3: Update CLI imports and argument parser**

Modify the imports in `emulation/charx_v190/pentest/firmware_browser/cli.py`:

```python
import argparse
import sys
from pathlib import Path

from firmware_browser.engines.codeql_engine import codeql_plan, codeql_version
from firmware_browser.models import BrowserContext
from firmware_browser.orchestrator import run_scan
from firmware_browser.paths import resolve_rootfs
from firmware_browser.runtime import default_lab_dir, resolve_runtime_rootfs
from firmware_browser.skill_context import export_skill_context
```

Replace `context_from_args` and `add_rootfs_args` with:

```python
def context_from_args(args: argparse.Namespace) -> BrowserContext:
    if args.rootfs:
        return BrowserContext(
            rootfs=resolve_rootfs(args.rootfs),
            output_dir=Path(args.output_dir).resolve(),
            product_name=args.product_name,
            runtime_source="manual-rootfs",
        )

    selection = resolve_runtime_rootfs(
        lab_dir=Path(args.lab_dir).expanduser(),
        runtime=args.runtime,
        run_id=args.run_id,
    )
    for warning in selection.warning_list():
        print(f"warning: {warning}", file=sys.stderr)

    return BrowserContext(
        rootfs=selection.rootfs,
        output_dir=Path(args.output_dir).resolve(),
        product_name=args.product_name,
        runtime_source=selection.source,
        runtime_run_id=selection.run_id,
        runtime_lab_dir=str(selection.lab_dir),
        runtime_warnings=tuple(selection.warning_list()),
    )


def add_rootfs_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--rootfs")
    parser.add_argument("--runtime", choices=["active", "ro"], default="active")
    parser.add_argument("--lab-dir", default=str(default_lab_dir()))
    parser.add_argument("--run-id", default="")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--product-name", default="generic-firmware")
```

- [ ] **Step 4: Run CLI tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_cli.py -q
```

Expected: all CLI tests pass.

- [ ] **Step 5: Run affected package tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_firmware_browser_runtime.py tests/test_firmware_browser_cli.py tests/test_firmware_browser_orchestrator.py tests/test_firmware_browser_skill_context.py -q
```

Expected: all selected tests pass.

- [ ] **Step 6: Commit CLI runtime default**

Run:

```bash
git add emulation/charx_v190/pentest/firmware_browser/cli.py emulation/charx_v190/pentest/tests/test_firmware_browser_cli.py
git commit -m "feat: default code browser to active runtime rootfs"
```

---

### Task 4: Documentation Update

**Files:**
- Modify: `document/charx_sec_3100_local_pentest_workstation_guide_vi.md`
- Modify: `emulation/charx_v190/pentest/README.md`

- [ ] **Step 1: Update Vietnamese guide examples**

In `document/charx_sec_3100_local_pentest_workstation_guide_vi.md`, replace the current `code-browser` example block with:

````markdown
Ví dụ mặc định thao tác trên runtime đang emulate:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --product-name charx-sec-3100-v190
.\emulation\charx_v190\charx-pentest.cmd code-browser binary-map
.\emulation\charx_v190\charx-pentest.cmd code-browser codeql-plan
.\emulation\charx_v190\charx-pentest.cmd code-browser skill-context
```

Mặc định `--runtime active` sẽ dùng `runs/<run_id>/rootfs_rw` của session đang chạy. Nếu không tìm thấy active run, browser ghi cảnh báo và fallback sang `rootfs_ro` trong lab. Khi cần scan artifact tĩnh ở ổ D, dùng `--rootfs D:\CHARXSEC\work\firmware_v190_rootfs` để override thủ công.
````

- [ ] **Step 2: Update pentest README runtime wording**

In `emulation/charx_v190/pentest/README.md`, replace the scan command and add the runtime note:

````markdown
```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --product-name generic-firmware
```

Mặc định `code-browser` dùng `--runtime active`: ưu tiên active `runs/<run_id>/rootfs_rw`; nếu chưa có active run thì fallback sang `rootfs_ro` và ghi `warning`. `--rootfs D:\path\to\rootfs` vẫn là manual override cho static artifact.
````

- [ ] **Step 3: Run documentation content check**

Run:

```powershell
rg -n "--runtime active|rootfs_rw|rootfs_ro|--rootfs" document/charx_sec_3100_local_pentest_workstation_guide_vi.md emulation/charx_v190/pentest/README.md
```

Expected: both files mention runtime active, `rootfs_rw`, `rootfs_ro`, and `--rootfs`.

- [ ] **Step 4: Commit docs**

Run:

```bash
git add document/charx_sec_3100_local_pentest_workstation_guide_vi.md emulation/charx_v190/pentest/README.md
git commit -m "docs: document runtime-aware code browser"
```

---

### Task 5: Final Verification

**Files:**
- Modify only if verification reveals a small bug.

- [ ] **Step 1: Run full Python tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

Expected: all tests pass.

- [ ] **Step 2: Run CLI help smoke**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser scan --help
```

Expected: help lists `--rootfs`, `--runtime {active,ro}`, `--lab-dir`, and `--run-id`.

- [ ] **Step 3: Run runtime active smoke**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd code-browser inventory --product-name charx-sec-3100-v190
```

Expected:

- Exit code `0`.
- If full-service is running, `inventory.json` uses `/home/<user>/charx_labs/charx_v190/runs/<run_id>/rootfs_rw`.
- If no run is active, stderr includes `warning: No active runtime rootfs_rw found; using lab rootfs_ro.` and `inventory.json` uses `/home/<user>/charx_labs/charx_v190/rootfs_ro`.

- [ ] **Step 4: Run manual rootfs override smoke**

Run:

```powershell
if (Test-Path D:\CHARXSEC\work\firmware_v190_rootfs) {
  .\emulation\charx_v190\charx-pentest.cmd code-browser inventory --rootfs D:\CHARXSEC\work\firmware_v190_rootfs --product-name charx-sec-3100-v190
}
```

Expected: manual override still works and records `"source": "manual-rootfs"` in `inventory.json`.

- [ ] **Step 5: Check ignored artifacts and worktree state**

Run:

```powershell
git status --short
git check-ignore -v emulation/charx_v190/pentest/evidence/code_browser/inventory.json
git check-ignore -v emulation/charx_v190/pentest/evidence/code_browser/findings.jsonl
git check-ignore -v emulation/charx_v190/pentest/evidence/code_browser/skill_context.json
```

Expected: generated evidence is ignored and no unexpected tracked files remain.

- [ ] **Step 6: Commit only if final verification required fixes**

If verification required code or docs changes:

```bash
git add emulation/charx_v190/pentest document
git commit -m "test: verify runtime-aware code browser"
```

If there are no tracked changes, do not create an empty commit.

---

## Self-Review

- Spec coverage: tasks implement default `--runtime active`, active `rootfs_rw` resolution, `rootfs_ro` fallback warning, manual `--rootfs` override, runtime metadata, docs, and final verification.
- Placeholder scan: no red-flag placeholder tokens remain.
- Type consistency: `RuntimeSelection`, `resolve_runtime_rootfs`, `BrowserContext.runtime_payload`, `runtime_source`, `runtime_run_id`, `runtime_lab_dir`, and `runtime_warnings` are defined before later tasks use them.
- Scope check: engines remain product-neutral; CHARX lab layout logic is isolated in `runtime.py` and activated only when CLI needs runtime rootfs resolution.
