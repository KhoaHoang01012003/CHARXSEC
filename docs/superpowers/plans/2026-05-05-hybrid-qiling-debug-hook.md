# Hybrid Qiling Debug Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make hook/debug workflows behave like dynamic emulation tools by default: use the active runtime `rootfs_rw`, run instrumentation through Qiling's built-in hook/debug/coverage APIs, and keep QEMU full-service as the runtime baseline for comparison.

**Architecture:** The hybrid design has two lanes. QEMU/full-service remains the baseline runtime truth for status and comparison, while Qiling is the controlled instrumentation lane for hook, trace, coverage, and gdbserver sessions. The pentest wrappers stay as thin convenience/evidence bridges, and the Qiling runner owns runtime rootfs resolution and direct Qiling API use.

**Tech Stack:** Python 3.11, argparse, pytest, Qiling (`Qiling`, `ql.hook_*`, `ql.os.set_syscall`, `ql.debugger`, `qiling.extensions.coverage`), existing PowerShell/WSL launchers.

---

## File Structure

- `emulation/charx_v190/qiling/scripts/runtime_resolver.py`: new shared resolver for Qiling workflows. It resolves manual `--rootfs`, active `runs/<runtime_run_id>/rootfs_rw`, and fallback `rootfs_ro`, with warning metadata.
- `emulation/charx_v190/qiling/scripts/qiling_runner.py`: make `--rootfs` optional, add `--runtime active|ro`, `--runtime-run-id`, `--lab-dir`, and runtime metadata in `runner_invocation`. Keep `--run-id` as the Qiling evidence run id only.
- `emulation/charx_v190/qiling/scripts/qiling_lab.sh`: update usage text so users see runtime-aware options.
- `emulation/charx_v190/pentest/scripts/hook_runner.py`: keep it as a thin bridge, add runtime args, pass them to Qiling runner, and record runtime mode in evidence details.
- `emulation/charx_v190/pentest/scripts/debug_runner.py`: keep `qemu-status` baseline, make `qiling-gdb` runtime-aware, and pass runtime args to Qiling's built-in `ql.debugger` path.
- `emulation/charx_v190/pentest/tests/test_qiling_runtime_resolver.py`: tests for resolver behavior.
- `emulation/charx_v190/pentest/tests/test_qiling_runner_runtime.py`: tests that Qiling runner resolves runtime and records metadata without launching Qiling.
- `emulation/charx_v190/pentest/tests/test_hook_runner.py`: update command-building tests.
- `emulation/charx_v190/pentest/tests/test_debug_runner.py`: update qiling-gdb command tests.
- `emulation/charx_v190/qiling/README.md` and `emulation/charx_v190/pentest/README.md`: explain hybrid model and default runtime behavior.

---

### Task 1: Qiling Runtime Resolver

**Files:**
- Create: `emulation/charx_v190/qiling/scripts/runtime_resolver.py`
- Test: `emulation/charx_v190/pentest/tests/test_qiling_runtime_resolver.py`

- [ ] **Step 1: Write failing resolver tests**

Create `emulation/charx_v190/pentest/tests/test_qiling_runtime_resolver.py`:

```python
import sys
from pathlib import Path


QILING_SCRIPTS = Path(__file__).resolve().parents[2] / "qiling" / "scripts"
if str(QILING_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(QILING_SCRIPTS))

from runtime_resolver import resolve_runtime_rootfs  # noqa: E402


def test_manual_rootfs_wins_over_runtime(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    (lab / "rootfs_ro").mkdir(parents=True)
    manual = tmp_path / "manual-rootfs"
    manual.mkdir()

    selection = resolve_runtime_rootfs(
        rootfs=manual,
        lab_dir=lab,
        runtime="active",
        runtime_run_id="run-1",
        last_run_file=None,
    )

    assert selection.rootfs == manual.resolve()
    assert selection.source == "manual-rootfs"
    assert selection.run_id == ""
    assert selection.warning_list() == []


def test_active_runtime_uses_session_rootfs_rw(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    active = lab / "runs" / "run-1" / "rootfs_rw"
    active.mkdir(parents=True)
    (lab / "state").mkdir()
    (lab / "state" / "wbm_session.env").write_text('RUN_ID="run-1"\n', encoding="utf-8")
    (lab / "rootfs_ro").mkdir()

    selection = resolve_runtime_rootfs(
        rootfs=None,
        lab_dir=lab,
        runtime="active",
        runtime_run_id=None,
        last_run_file=None,
    )

    assert selection.rootfs == active.resolve()
    assert selection.source == "active-rootfs-rw"
    assert selection.run_id == "run-1"
    assert selection.warning_list() == []


def test_active_runtime_uses_last_run_when_session_state_missing(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    active = lab / "runs" / "run-last" / "rootfs_rw"
    active.mkdir(parents=True)
    (lab / "rootfs_ro").mkdir()
    last_run = tmp_path / "last-run-id"
    last_run.write_text("run-last\n", encoding="utf-8")

    selection = resolve_runtime_rootfs(
        rootfs=None,
        lab_dir=lab,
        runtime="active",
        runtime_run_id=None,
        last_run_file=last_run,
    )

    assert selection.rootfs == active.resolve()
    assert selection.run_id == "run-last"
    assert selection.source == "active-rootfs-rw"


def test_active_runtime_falls_back_to_rootfs_ro_with_warning(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    rootfs_ro = lab / "rootfs_ro"
    rootfs_ro.mkdir(parents=True)

    selection = resolve_runtime_rootfs(
        rootfs=None,
        lab_dir=lab,
        runtime="active",
        runtime_run_id=None,
        last_run_file=None,
    )

    assert selection.rootfs == rootfs_ro.resolve()
    assert selection.source == "fallback-rootfs-ro"
    assert selection.warning_list() == ["No active runtime rootfs_rw found; using lab rootfs_ro."]


def test_runtime_ro_uses_rootfs_ro(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    rootfs_ro = lab / "rootfs_ro"
    rootfs_ro.mkdir(parents=True)

    selection = resolve_runtime_rootfs(
        rootfs=None,
        lab_dir=lab,
        runtime="ro",
        runtime_run_id=None,
        last_run_file=None,
    )

    assert selection.rootfs == rootfs_ro.resolve()
    assert selection.source == "rootfs-ro"
```

- [ ] **Step 2: Run resolver tests to verify failure**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_qiling_runtime_resolver.py -q
```

Expected: fail with `ModuleNotFoundError: No module named 'runtime_resolver'`.

- [ ] **Step 3: Implement runtime resolver**

Create `emulation/charx_v190/qiling/scripts/runtime_resolver.py`:

```python
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
```

- [ ] **Step 4: Run resolver tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_qiling_runtime_resolver.py -q
```

Expected: `5 passed`.

- [ ] **Step 5: Commit resolver**

Run:

```bash
git add emulation/charx_v190/qiling/scripts/runtime_resolver.py emulation/charx_v190/pentest/tests/test_qiling_runtime_resolver.py
git commit -m "feat: add qiling runtime rootfs resolver"
```

---

### Task 2: Qiling Runner Runtime-Aware Defaults

**Files:**
- Modify: `emulation/charx_v190/qiling/scripts/qiling_runner.py`
- Test: `emulation/charx_v190/pentest/tests/test_qiling_runner_runtime.py`

- [ ] **Step 1: Write failing Qiling runner tests**

Create `emulation/charx_v190/pentest/tests/test_qiling_runner_runtime.py`:

```python
import sys
from pathlib import Path


QILING_SCRIPTS = Path(__file__).resolve().parents[2] / "qiling" / "scripts"
if str(QILING_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(QILING_SCRIPTS))

import qiling_runner  # noqa: E402


def test_parse_args_accepts_runtime_without_rootfs(tmp_path: Path) -> None:
    args = qiling_runner.parse_args([
        "--mode",
        "static-map",
        "--service",
        "charx-website",
        "--lab-dir",
        str(tmp_path / "lab"),
    ])

    assert args.rootfs is None
    assert args.runtime == "active"
    assert args.runtime_run_id is None
    assert args.lab_dir == tmp_path / "lab"


def test_apply_runtime_selection_updates_args_and_metadata(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    rootfs_rw = lab / "runs" / "run-1" / "rootfs_rw"
    rootfs_rw.mkdir(parents=True)
    (lab / "state").mkdir()
    (lab / "state" / "wbm_session.env").write_text("RUN_ID=run-1\n", encoding="utf-8")
    (lab / "rootfs_ro").mkdir()
    args = qiling_runner.parse_args([
        "--mode",
        "static-map",
        "--service",
        "charx-website",
        "--lab-dir",
        str(lab),
    ])

    qiling_runner.apply_runtime_selection(args, last_run_file=None)

    assert args.rootfs == rootfs_rw.resolve()
    assert args.qemu_lab == lab.resolve()
    assert args.runtime_metadata["source"] == "active-rootfs-rw"
    assert args.runtime_metadata["runtime_run_id"] == "run-1"


def test_apply_runtime_selection_ignores_evidence_run_id_for_rootfs_choice(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    rootfs_rw = lab / "runs" / "device-run-1" / "rootfs_rw"
    rootfs_rw.mkdir(parents=True)
    (lab / "state").mkdir()
    (lab / "state" / "wbm_session.env").write_text("RUN_ID=device-run-1\n", encoding="utf-8")
    (lab / "rootfs_ro").mkdir()
    args = qiling_runner.parse_args([
        "--mode",
        "static-map",
        "--service",
        "charx-website",
        "--lab-dir",
        str(lab),
        "--run-id",
        "qiling-evidence-1",
    ])

    qiling_runner.apply_runtime_selection(args, last_run_file=None)

    assert args.run_id == "qiling-evidence-1"
    assert args.rootfs == rootfs_rw.resolve()
    assert args.runtime_metadata["runtime_run_id"] == "device-run-1"


def test_apply_runtime_selection_keeps_manual_rootfs(tmp_path: Path) -> None:
    lab = tmp_path / "lab"
    (lab / "rootfs_ro").mkdir(parents=True)
    manual = tmp_path / "manual-rootfs"
    manual.mkdir()
    args = qiling_runner.parse_args([
        "--mode",
        "static-map",
        "--service",
        "charx-website",
        "--rootfs",
        str(manual),
        "--lab-dir",
        str(lab),
    ])

    qiling_runner.apply_runtime_selection(args, last_run_file=None)

    assert args.rootfs == manual.resolve()
    assert args.runtime_metadata["source"] == "manual-rootfs"
```

- [ ] **Step 2: Run Qiling runner tests to verify failure**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_qiling_runner_runtime.py -q
```

Expected: fail because `parse_args` does not accept an argv list or runtime args.

- [ ] **Step 3: Update Qiling runner imports**

In `emulation/charx_v190/qiling/scripts/qiling_runner.py`, add this import near the existing imports:

```python
from runtime_resolver import default_lab_dir, resolve_runtime_rootfs
```

- [ ] **Step 4: Change parser to accept argv and runtime options**

Replace `parse_args()` with:

```python
def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="CHARX SEC-3100 V190 Qiling analysis runner.")
    parser.add_argument("--mode", choices=["matrix", "static-map", "instrumented-run", "fuzz-harness"], required=True)
    parser.add_argument("--service", default=None, help="Service name from service_matrix.json, or 'all' for static-map.")
    parser.add_argument("--rootfs", type=Path, default=None)
    parser.add_argument("--runtime", choices=["active", "ro"], default="active")
    parser.add_argument("--runtime-run-id", default=None, help="Optional QEMU/full-service run id for selecting runs/<id>/rootfs_rw.")
    parser.add_argument("--lab-dir", type=Path, default=default_lab_dir())
    parser.add_argument("--qemu-lab", type=Path, default=None)
    parser.add_argument("--evidence-root", type=Path, default=None, help="Optional writable base directory for evidence. run_id is appended.")
    parser.add_argument("--run-id", default=None)
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--coverage", choices=["none", "drcov", "basic"], default="none")
    parser.add_argument("--debugger", choices=["none", "gdb", "idapro", "qdb"], default="none")
    parser.add_argument("--debug-port", type=int, default=9999)
    parser.add_argument("--hooks", default=DEFAULT_HOOKS)
    parser.add_argument("--max-events", type=int, default=5000)
    parser.add_argument("--seed", default=None)
    parser.add_argument("--max-seeds", type=int, default=10)
    parser.add_argument("--extra-arg", action="append", default=[])
    return parser.parse_args(argv)
```

- [ ] **Step 5: Add runtime selection function**

Add this function after `parse_args`:

```python
def apply_runtime_selection(args: argparse.Namespace, last_run_file: Path | None = Path("/tmp/charx-full-last-run-id")) -> None:
    selection = resolve_runtime_rootfs(
        rootfs=args.rootfs,
        lab_dir=args.lab_dir,
        runtime=args.runtime,
        runtime_run_id=args.runtime_run_id,
        last_run_file=last_run_file,
    )
    for warning in selection.warning_list():
        print(f"warning: {warning}", file=sys.stderr)

    args.rootfs = selection.rootfs
    args.qemu_lab = (args.qemu_lab or selection.lab_dir).expanduser().resolve()
    args.runtime_metadata = selection.metadata()
```

- [ ] **Step 6: Use runtime selection in main and evidence**

In `main()`, keep the existing `args = parse_args()` call, then replace:

```python
    args.run_id = args.run_id or utc_run_id()
    args.rootfs = args.rootfs.resolve()
    args.qemu_lab = args.qemu_lab.resolve()
```

with:

```python
    apply_runtime_selection(args)
    args.run_id = args.run_id or utc_run_id()
```

In the `ev.write("runner_invocation", ...)` call, add:

```python
            runtime=args.runtime_metadata,
```

- [ ] **Step 7: Run Qiling runner tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_qiling_runtime_resolver.py tests/test_qiling_runner_runtime.py -q
```

Expected: all tests pass.

- [ ] **Step 8: Commit Qiling runner runtime defaults**

Run:

```bash
git add emulation/charx_v190/qiling/scripts/qiling_runner.py emulation/charx_v190/pentest/tests/test_qiling_runner_runtime.py
git commit -m "feat: default qiling runner to active runtime rootfs"
```

---

### Task 3: Thin Hook Wrapper Runtime Pass-Through

**Files:**
- Modify: `emulation/charx_v190/pentest/scripts/hook_runner.py`
- Test: `emulation/charx_v190/pentest/tests/test_hook_runner.py`

- [ ] **Step 1: Write failing hook command tests**

Append to `emulation/charx_v190/pentest/tests/test_hook_runner.py`:

```python
def test_hook_command_passes_runtime_active_by_default() -> None:
    args = hook_runner.build_parser().parse_args(["--mode", "run", "--service", "charx-website"])

    command = hook_runner.command_for(args, Path("/qiling_lab.sh"))

    assert command == [
        "/qiling_lab.sh",
        "run",
        "--service",
        "charx-website",
        "--runtime",
        "active",
        "--timeout",
        "10",
        "--hooks",
        "files,sockets,syscalls,blocks,memory",
    ]


def test_hook_command_passes_manual_rootfs_and_lab_dir() -> None:
    args = hook_runner.build_parser().parse_args([
        "--mode",
        "static-map",
        "--service",
        "charx-website",
        "--rootfs",
        "/tmp/rootfs",
        "--lab-dir",
        "/tmp/lab",
        "--runtime-run-id",
        "device-run-1",
        "--run-id",
        "qiling-run-1",
    ])

    command = hook_runner.command_for(args, Path("/qiling_lab.sh"))

    assert command == [
        "/qiling_lab.sh",
        "static-map",
        "--service",
        "charx-website",
        "--runtime",
        "active",
        "--lab-dir",
        "/tmp/lab",
        "--runtime-run-id",
        "device-run-1",
        "--run-id",
        "qiling-run-1",
        "--rootfs",
        "/tmp/rootfs",
    ]
```

- [ ] **Step 2: Run hook tests to verify failure**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_hook_runner.py::test_hook_command_passes_runtime_active_by_default tests/test_hook_runner.py::test_hook_command_passes_manual_rootfs_and_lab_dir -q
```

Expected: fail because parser does not know `--rootfs`/`--lab-dir`/`--runtime-run-id`, and default command lacks `--runtime active`.

- [ ] **Step 3: Add runtime command helper**

In `emulation/charx_v190/pentest/scripts/hook_runner.py`, add this helper before `command_for`:

```python
def runtime_args(args: argparse.Namespace) -> list[str]:
    values = ["--runtime", args.runtime]
    if args.lab_dir:
        values.extend(["--lab-dir", args.lab_dir])
    if args.runtime_run_id:
        values.extend(["--runtime-run-id", args.runtime_run_id])
    if args.run_id:
        values.extend(["--run-id", args.run_id])
    if args.rootfs:
        values.extend(["--rootfs", args.rootfs])
    return values
```

- [ ] **Step 4: Update command_for**

Replace `command_for` with:

```python
def command_for(args: argparse.Namespace, entrypoint: Path) -> list[str]:
    qiling_cmd = str(entrypoint)
    service = args.service
    timeout = str(args.timeout)
    common = [qiling_cmd, args.mode if args.mode != "run" else "run", "--service", service, *runtime_args(args)]

    if args.mode == "static-map":
        return common
    if args.mode == "fuzz":
        return [
            qiling_cmd,
            "fuzz",
            "--service",
            service,
            *runtime_args(args),
            "--timeout",
            timeout,
            "--max-seeds",
            "5",
        ]
    return [
        qiling_cmd,
        "run",
        "--service",
        service,
        *runtime_args(args),
        "--timeout",
        timeout,
        "--hooks",
        args.hooks,
    ]
```

- [ ] **Step 5: Add parser args**

In `build_parser`, add after `parser.add_argument("--service", default="charx-website")`:

```python
    parser.add_argument("--runtime", choices=("active", "ro"), default="active")
    parser.add_argument("--lab-dir", default="")
    parser.add_argument("--runtime-run-id", default="", help="Optional QEMU/full-service run id used to select rootfs_rw.")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--rootfs", default="")
```

- [ ] **Step 6: Add runtime details to evidence**

Keep `emit(...)` unchanged. In `run(args)`, add the selected runtime args into each `details` dictionary passed to `emit(...)`:

```python
"runtime_args": runtime_args(args),
```

For the normal completion call, change:

```python
        details=captured_details(stdout_capture, stderr_capture),
```

to:

```python
        details={**captured_details(stdout_capture, stderr_capture), "runtime_args": runtime_args(args)},
```

Apply the same pattern to the missing wrapper, timeout, and `OSError` emit calls.

- [ ] **Step 7: Run hook tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_hook_runner.py -q
```

Expected: all hook tests pass.

- [ ] **Step 8: Commit hook wrapper**

Run:

```bash
git add emulation/charx_v190/pentest/scripts/hook_runner.py emulation/charx_v190/pentest/tests/test_hook_runner.py
git commit -m "feat: pass runtime rootfs options through hook runner"
```

---

### Task 4: Debug Wrapper Runtime-Aware Qiling GDB

**Files:**
- Modify: `emulation/charx_v190/pentest/scripts/debug_runner.py`
- Test: `emulation/charx_v190/pentest/tests/test_debug_runner.py`

- [ ] **Step 1: Write failing debug command tests**

Modify `test_qiling_gdb_records_observation_before_launch` in `emulation/charx_v190/pentest/tests/test_debug_runner.py` so the call becomes:

```python
    assert debug_runner.qiling_gdb(
        service="charx-website",
        port=9999,
        runtime="active",
        lab_dir="/tmp/lab",
        runtime_run_id="device-run-1",
        run_id="qiling-run-1",
        rootfs="",
    ) == 0
```

And change the expected command to:

```python
    assert calls[0][0] == [
        str(debug_runner.QILING_SH),
        "run",
        "--service",
        "charx-website",
        "--runtime",
        "active",
        "--lab-dir",
        "/tmp/lab",
        "--runtime-run-id",
        "device-run-1",
        "--run-id",
        "qiling-run-1",
        "--debugger",
        "gdb",
        "--debug-port",
        "9999",
        "--timeout",
        "0",
    ]
```

- [ ] **Step 2: Run debug test to verify failure**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_debug_runner.py::test_qiling_gdb_records_observation_before_launch -q
```

Expected: fail with `TypeError` because `qiling_gdb` does not accept runtime args.

- [ ] **Step 3: Add runtime arg helper**

In `emulation/charx_v190/pentest/scripts/debug_runner.py`, add before `qiling_gdb`:

```python
def runtime_args(runtime: str, lab_dir: str, runtime_run_id: str, run_id: str, rootfs: str) -> list[str]:
    values = ["--runtime", runtime]
    if lab_dir:
        values.extend(["--lab-dir", lab_dir])
    if runtime_run_id:
        values.extend(["--runtime-run-id", runtime_run_id])
    if run_id:
        values.extend(["--run-id", run_id])
    if rootfs:
        values.extend(["--rootfs", rootfs])
    return values
```

- [ ] **Step 4: Update qiling_gdb signature and command**

Replace the `qiling_gdb` signature and command construction with:

```python
def qiling_gdb(
    service: str,
    port: int,
    runtime: str,
    lab_dir: str,
    runtime_run_id: str,
    run_id: str,
    rootfs: str,
) -> int:
    entrypoint = qiling_entrypoint()
    port_text = str(port)
    selected_runtime_args = runtime_args(runtime, lab_dir, runtime_run_id, run_id, rootfs)
    command = [
        str(entrypoint),
        "run",
        "--service",
        service,
        *selected_runtime_args,
        "--debugger",
        "gdb",
        "--debug-port",
        port_text,
        "--timeout",
        "0",
    ]
    details: dict[str, Any] = {
        "connect_hint": f"gdb-multiarch then target remote localhost:{port_text}",
        "runtime_args": selected_runtime_args,
        "qiling_debugger": "ql.debugger",
    }
    if not entrypoint.exists():
        details["missing_path"] = str(entrypoint)

    record(
        event_type="qiling_gdb_start",
        label="observed_qiling_target",
        component=service,
        summary=f"Start Qiling gdbserver for {service} on port {port_text}",
        command=command,
        exit_code=None,
        artifact_path=None,
        details=details,
    )

    if not entrypoint.exists():
        print(f"Qiling wrapper is missing: {entrypoint}", file=sys.stderr)
        return MISSING_TOOL_EXIT_CODE

    return subprocess.call(command, cwd=REPO_ROOT)
```

- [ ] **Step 5: Add CLI args and call new signature**

In `build_parser`, after `gdb.add_argument("--port", type=tcp_port, default=9999)`, add:

```python
    gdb.add_argument("--runtime", choices=("active", "ro"), default="active")
    gdb.add_argument("--lab-dir", default="")
    gdb.add_argument("--runtime-run-id", default="", help="Optional QEMU/full-service run id used to select rootfs_rw.")
    gdb.add_argument("--run-id", default="")
    gdb.add_argument("--rootfs", default="")
```

In `main`, replace:

```python
        return qiling_gdb(args.service, args.port)
```

with:

```python
        return qiling_gdb(args.service, args.port, args.runtime, args.lab_dir, args.runtime_run_id, args.run_id, args.rootfs)
```

- [ ] **Step 6: Run debug tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest tests/test_debug_runner.py -q
```

Expected: all debug tests pass.

- [ ] **Step 7: Commit debug wrapper**

Run:

```bash
git add emulation/charx_v190/pentest/scripts/debug_runner.py emulation/charx_v190/pentest/tests/test_debug_runner.py
git commit -m "feat: pass runtime rootfs options through qiling debugger"
```

---

### Task 5: Qiling Lab Usage And Documentation

**Files:**
- Modify: `emulation/charx_v190/qiling/scripts/qiling_lab.sh`
- Modify: `emulation/charx_v190/qiling/README.md`
- Modify: `emulation/charx_v190/pentest/README.md`

- [ ] **Step 1: Update `qiling_lab.sh` usage text**

In `emulation/charx_v190/qiling/scripts/qiling_lab.sh`, replace the `Common runner args` block with:

```text
Common runner args:
  --runtime active|ro
  --lab-dir <path>
  --runtime-run-id <id>
  --run-id <id>
  --rootfs <path>
  --timeout <seconds>
  --coverage none|drcov|basic
  --debugger none|gdb|idapro
  --debug-port <port>
  --hooks files,sockets,syscalls,blocks,memory

Default behavior:
  --runtime active resolves active runs/<runtime_run_id>/rootfs_rw from session state or /tmp/charx-full-last-run-id.
  --runtime-run-id selects a specific QEMU/full-service run rootfs_rw.
  --run-id is the Qiling evidence id and does not choose rootfs_rw.
  If no active run exists, the runner warns and falls back to rootfs_ro.
  --rootfs remains a manual override for static artifacts.
```

- [ ] **Step 2: Update Qiling README**

In `emulation/charx_v190/qiling/README.md`, add this section after the command examples:

```markdown
## Hybrid Runtime Model

QEMU/full-service is the baseline runtime truth. Qiling is the instrumentation lane for hooks, coverage, syscall tracing and debugger sessions.

By default, Qiling commands use `--runtime active`, which resolves the active `runs/<runtime_run_id>/rootfs_rw` from the WSL lab session state or `/tmp/charx-full-last-run-id`. If no active run is found, Qiling prints a warning and falls back to `rootfs_ro`. Use `--runtime-run-id <id>` to pin a specific active runtime, and use `--rootfs <path>` only when intentionally analyzing a static artifact. `--run-id` remains the Qiling evidence id.

Examples:

```bash
qiling_lab.sh run --service charx-website --hooks files,sockets,syscalls,blocks,memory
qiling_lab.sh run --service charx-website --debugger gdb --debug-port 9999 --timeout 0
qiling_lab.sh static-map --service charx-website --runtime ro
```
```

- [ ] **Step 3: Update pentest README**

In `emulation/charx_v190/pentest/README.md`, replace the debug paragraph with:

```markdown
## Debug Và Hook Theo Mô Hình Hybrid

`debug qemu-status` kiểm tra full-service runtime baseline. Đây là nơi dùng để đối chiếu hành vi thật hơn của lab.

`hook` và `debug qiling-gdb` dùng Qiling làm instrumentation lane. Mặc định chúng truyền `--runtime active`, nên Qiling chạy trên active `runs/<runtime_run_id>/rootfs_rw` lấy từ session state hoặc `/tmp/charx-full-last-run-id`; nếu chưa có active run thì fallback `rootfs_ro` kèm warning. Dùng `--runtime-run-id` khi muốn ghim đúng một QEMU/full-service run cụ thể. `--run-id` chỉ là mã evidence của Qiling. Hook, syscall tracing, coverage và gdbserver đều đi qua API có sẵn của Qiling như `ql.hook_block`, `ql.hook_code`, `ql.os.set_syscall`, `ql.debugger` và `qiling.extensions.coverage`.

```powershell
.\emulation\charx_v190\charx-pentest.cmd hook --service charx-website --mode run --timeout 20
.\emulation\charx_v190\charx-pentest.cmd debug qiling-gdb --service charx-website --port 9999
.\emulation\charx_v190\charx-pentest.cmd debug qemu-status
```
```

- [ ] **Step 4: Run documentation content check**

Run:

```powershell
rg -n -- "Hybrid|--runtime active|--runtime-run-id|rootfs_rw|ql\\.debugger|ql\\.hook|qiling\\.extensions\\.coverage|qemu-status" emulation/charx_v190/qiling/README.md emulation/charx_v190/pentest/README.md emulation/charx_v190/qiling/scripts/qiling_lab.sh
```

Expected: all key phrases are present.

- [ ] **Step 5: Commit docs**

Run:

```bash
git add emulation/charx_v190/qiling/scripts/qiling_lab.sh emulation/charx_v190/qiling/README.md emulation/charx_v190/pentest/README.md
git commit -m "docs: document hybrid qiling debug hook workflow"
```

---

### Task 6: Final Verification

**Files:**
- Modify only if verification reveals a small bug.

- [ ] **Step 1: Run full pentest tests**

Run:

```bash
cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation/emulation/charx_v190/pentest
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

Expected: all tests pass.

- [ ] **Step 2: Run Qiling CLI help smoke**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd hook --mode run --service charx-website --timeout 1 --runtime ro
```

Expected:

- If Qiling venv is available, command starts the Qiling wrapper and records evidence.
- If Qiling venv is missing, failure is controlled and evidence is labeled `observed_qiling_target`.
- Command includes runtime args in evidence details.

- [ ] **Step 3: Run Qiling runner parser smoke without launching Qiling**

Run:

```powershell
wsl -d Debian -- bash -lc "cd /mnt/d/CHARXSEC/.worktrees/charx-pentest-workstation && python3 emulation/charx_v190/qiling/scripts/qiling_runner.py --mode matrix | head -n 5"
```

Expected: matrix JSON begins printing and exit code is `0`.

- [ ] **Step 4: Run debug help smoke**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd debug qiling-gdb --help
```

Expected: help lists `--runtime`, `--lab-dir`, `--runtime-run-id`, `--run-id`, and `--rootfs`.

- [ ] **Step 5: Run qemu baseline status**

Run:

```powershell
.\emulation\charx_v190\charx-pentest.cmd debug qemu-status
```

Expected: command exits `0` or reports controlled full-service status output; evidence label is `observed_runtime_qemu`.

- [ ] **Step 6: Check ignored artifacts and worktree state**

Run:

```powershell
git status --short
git check-ignore -v emulation/charx_v190/pentest/evidence/hook/observations.jsonl
git check-ignore -v emulation/charx_v190/pentest/evidence/debug/observations.jsonl
```

Expected: generated evidence is ignored and no unexpected tracked artifacts remain.

- [ ] **Step 7: Commit verification fixes only if needed**

If verification required code or docs changes:

```bash
git add emulation/charx_v190/qiling emulation/charx_v190/pentest
git commit -m "test: verify hybrid qiling debug hook workflow"
```

If there are no tracked changes, do not create an empty commit.

---

## Self-Review

- Spec coverage: tasks implement Hybrid behavior, active `rootfs_rw` defaults, `rootfs_ro` fallback warning, manual `--rootfs`, separate `--runtime-run-id` versus Qiling evidence `--run-id`, QEMU baseline status preservation, Qiling built-in hook/debug/coverage API use, and documentation.
- Placeholder scan: no red-flag placeholder tokens remain.
- Type consistency: `RuntimeSelection`, `resolve_runtime_rootfs`, `apply_runtime_selection`, `runtime_args`, `runtime_run_id`, and runtime metadata names are defined before later tasks use them.
- Scope check: wrappers remain thin; deep hook/debug behavior stays in Qiling runner; no external tool is added beyond existing Qiling, gdb-compatible debugger, `file`, `readelf`, and `strings` static-map helpers.
