#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
QILING_DIR = SCRIPT_DIR.parent
MATRIX_PATH = QILING_DIR / "service_matrix.json"
DEFAULT_ROOTFS = Path("/home/khoa/charx_labs/charx_v190/rootfs_ro")
DEFAULT_QEMU_LAB = Path("/home/khoa/charx_labs/charx_v190")
DEFAULT_HOOKS = "files,sockets,syscalls,blocks,memory"


class JsonlEvidence:
    def __init__(self, path: Path, run_id: str, service: str, mode: str):
        self.path = path
        self.run_id = run_id
        self.service = service
        self.mode = mode
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, event_type: str, label: str = "observed_qiling_target", **fields: Any) -> None:
        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "run_id": self.run_id,
            "service": self.service,
            "mode": self.mode,
            "label": label,
            "event_type": event_type,
            "behavior_claim_allowed": False,
            "evidence_tier": fields.pop("evidence_tier", "Tier 0"),
            "confidence": fields.pop("confidence", "medium"),
        }
        event.update(fields)
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(event, sort_keys=True, default=str) + "\n")


def utc_run_id(prefix: str = "qiling") -> str:
    return f"{prefix}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"


def load_matrix() -> dict[str, Any]:
    return json.loads(MATRIX_PATH.read_text(encoding="utf-8"))


def service_map(matrix: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {svc["name"]: svc for svc in matrix["services"]}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def safe_file_fact(path: Path) -> dict[str, Any]:
    fact: dict[str, Any] = {
        "exists": path.exists(),
        "is_file": path.is_file() if path.exists() else False,
        "readable": False,
        "sha256": None,
        "size": None,
        "error": None,
    }
    if not fact["exists"] or not fact["is_file"]:
        return fact
    try:
        fact["size"] = path.stat().st_size
        fact["sha256"] = sha256(path)
        fact["readable"] = True
    except Exception as exc:
        fact["error"] = f"{type(exc).__name__}: {exc}"
    return fact


def run_cmd(argv: list[str], timeout: int = 15) -> dict[str, Any]:
    try:
        proc = subprocess.run(argv, text=True, capture_output=True, timeout=timeout, check=False)
        return {
            "argv": argv,
            "returncode": proc.returncode,
            "stdout": proc.stdout,
            "stderr": proc.stderr,
        }
    except Exception as exc:
        return {
            "argv": argv,
            "error": f"{type(exc).__name__}: {exc}",
        }


def host_path(rootfs: Path, guest_path: str) -> Path:
    return rootfs / guest_path.lstrip("/")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def choose_evidence_root(qemu_lab: Path, run_id: str, explicit_root: Path | None = None) -> tuple[Path, str | None]:
    if explicit_root is not None:
        return explicit_root / run_id, None

    preferred = qemu_lab / "evidence" / run_id
    try:
        preferred.mkdir(parents=True, exist_ok=True)
        return preferred, None
    except PermissionError as exc:
        fallback = QILING_DIR / "evidence" / run_id
        return fallback, f"{type(exc).__name__}: {exc}"


def prepare_run_dirs(qemu_lab: Path, run_id: str, service: str, mode: str, explicit_evidence_root: Path | None = None) -> dict[str, Path]:
    evidence_root, fallback_reason = choose_evidence_root(qemu_lab, run_id, explicit_evidence_root)
    target_dir = evidence_root / "qiling" / service / mode
    runtime_dir = target_dir / "runtime"

    dirs = {
        "evidence_root": evidence_root,
        "target_dir": target_dir,
        "runtime": runtime_dir,
        "data": runtime_dir / "data",
        "log": runtime_dir / "log",
        "identity": runtime_dir / "identity",
        "proc": runtime_dir / "proc",
        "sys": runtime_dir / "sys",
        "dev": runtime_dir / "dev",
        "run": runtime_dir / "run",
        "var_run": runtime_dir / "var" / "run",
        "var_volatile": runtime_dir / "var" / "volatile",
        "tmp": runtime_dir / "tmp",
        "coverage": target_dir / "coverage",
        "static": target_dir / "static",
        "logs": target_dir / "logs",
        "crashes": target_dir / "crashes",
        "seeds": target_dir / "seeds",
    }
    for p in dirs.values():
        p.mkdir(parents=True, exist_ok=True)

    if fallback_reason:
        write_text(
            evidence_root / "environment_limitation.txt",
            "Preferred WSL lab evidence directory is not writable by the current user.\n"
            f"Fallback evidence root: {evidence_root}\n"
            f"Reason: {fallback_reason}\n",
        )

    write_text(
        dirs["identity"] / "README.synthetic_lab_identity",
        "synthetic_lab_identity\nThis directory is a Qiling lab placeholder, not a real device identity.\n",
    )
    write_text(dirs["proc"] / "meminfo", "MemTotal:        524288 kB\nMemFree:         262144 kB\n")
    write_text(dirs["proc"] / "cpuinfo", "processor\t: 0\nmodel name\t: qiling-charx-v190-lab\n")
    write_text(dirs["sys"] / "README", "Synthetic sysfs placeholder for Qiling lab.\n")
    write_text(dirs["dev"] / "README", "Synthetic dev placeholder for Qiling lab.\n")
    return dirs


def matrix_mode() -> int:
    matrix = load_matrix()
    print(json.dumps(matrix, indent=2, sort_keys=True))
    return 0


def parse_needed_libraries(readelf_dynamic: str) -> list[str]:
    libs = []
    for line in readelf_dynamic.splitlines():
        match = re.search(r"Shared library: \[(.*?)\]", line)
        if match:
            libs.append(match.group(1))
    return libs


def route_hint(rootfs: Path) -> dict[str, Any]:
    route_path = host_path(rootfs, "/etc/charx/routePermissions.json")
    if not route_path.exists():
        return {"exists": False}
    try:
        data = json.loads(route_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"exists": True, "parse_error": f"{type(exc).__name__}: {exc}"}

    if isinstance(data, dict):
        route_count = len(data)
    elif isinstance(data, list):
        route_count = len(data)
    else:
        route_count = None
    return {
        "exists": True,
        "sha256": sha256(route_path),
        "type": type(data).__name__,
        "top_level_count": route_count,
    }


def static_map_service(args: argparse.Namespace, svc: dict[str, Any], ev: JsonlEvidence, dirs: dict[str, Path]) -> dict[str, Any]:
    rootfs = args.rootfs
    binary = host_path(rootfs, svc["binary"])
    resolved = binary.resolve(strict=False)
    if not binary.exists():
        result = {"service": svc["name"], "binary": svc["binary"], "exists": False}
        ev.write("static_binary_missing", confidence="high", result=result)
        return result

    file_info = run_cmd(["file", "-b", str(binary)])
    readelf_h = run_cmd(["readelf", "-h", str(binary)])
    readelf_d = run_cmd(["readelf", "-d", str(binary)])
    readelf_l = run_cmd(["readelf", "-l", str(binary)])
    strings = run_cmd(["strings", "-a", "-n", "6", str(binary)], timeout=30)
    strings_path = dirs["static"] / f"{svc['name']}.strings.txt"
    write_text(strings_path, strings.get("stdout", "")[:2_000_000])

    config_inventory = []
    for guest_config in svc.get("configs", []):
        p = host_path(rootfs, guest_config)
        fact = safe_file_fact(p)
        config_inventory.append(
            {
                "guest_path": guest_config,
                **fact,
            }
        )

    result = {
        "service": svc["name"],
        "tier": svc.get("tier"),
        "binary": svc["binary"],
        "host_path": str(binary),
        "resolved_host_path": str(resolved),
        "is_symlink": binary.is_symlink(),
        "exists": True,
        "sha256": sha256(resolved if resolved.exists() else binary),
        "size": (resolved if resolved.exists() else binary).stat().st_size,
        "file": file_info,
        "readelf_header": readelf_h,
        "needed_libraries": parse_needed_libraries(readelf_d.get("stdout", "")),
        "readelf_dynamic": readelf_d,
        "readelf_program_headers": readelf_l,
        "strings_path": str(strings_path),
        "configs": config_inventory,
        "route_permissions_hint": route_hint(rootfs) if svc["name"] == "charx-website" else None,
        "ports": svc.get("ports", []),
        "notes": svc.get("notes", ""),
    }
    out = dirs["static"] / f"{svc['name']}.static-map.json"
    write_text(out, json.dumps(result, indent=2, sort_keys=True, default=str) + "\n")
    ev.write("static_map_complete", confidence="high", output=str(out), binary=svc["binary"])
    return result


def import_qemu_baseline(args: argparse.Namespace, ev: JsonlEvidence, dirs: dict[str, Path]) -> None:
    baseline: dict[str, Any] = {
        "qemu_lab": str(args.qemu_lab),
        "last_run_id": None,
        "process_snapshot": run_cmd(["bash", "-lc", "ps -efww | egrep 'Charx|mosquitto|nginx' | grep -v egrep || true"]),
        "port_snapshot": run_cmd(["bash", "-lc", "ss -lntp 2>/dev/null | egrep ':(80|443|1883|4444|4999|5000|5001|5002|5555|2106|1603|9502|9555|502)\\b' || true"]),
    }
    last_run = Path("/tmp/charx-full-last-run-id")
    if last_run.exists():
        baseline["last_run_id"] = last_run.read_text(encoding="utf-8", errors="replace").strip()
    out = dirs["target_dir"] / "qemu_baseline_snapshot.json"
    write_text(out, json.dumps(baseline, indent=2, sort_keys=True, default=str) + "\n")
    ev.write("qemu_baseline_imported", label="observed_runtime_qemu", confidence="medium", output=str(out))


def qiling_imports() -> dict[str, Any]:
    try:
        from qiling import Qiling  # type: ignore
        from qiling.const import QL_INTERCEPT, QL_VERBOSE  # type: ignore
    except Exception as exc:
        raise RuntimeError(f"Qiling import failed: {type(exc).__name__}: {exc}") from exc
    return {"Qiling": Qiling, "QL_INTERCEPT": QL_INTERCEPT, "QL_VERBOSE": QL_VERBOSE}


def read_cstring_safe(ql: Any, ptr: int) -> str | None:
    if not isinstance(ptr, int) or ptr <= 0:
        return None
    try:
        value = ql.mem.string(ptr)
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        return str(value)
    except Exception:
        return None


def register_hooks(ql: Any, args: argparse.Namespace, ev: JsonlEvidence, dirs: dict[str, Path]) -> dict[str, Any]:
    imports = qiling_imports()
    QL_INTERCEPT = imports["QL_INTERCEPT"]
    hook_names = {h.strip() for h in (args.hooks or "").split(",") if h.strip()}
    registered: dict[str, Any] = {"requested": sorted(hook_names), "registered": [], "failed": []}
    event_count = {"blocks": 0, "code": 0, "memory": 0, "syscalls": 0}

    def maybe_log(kind: str) -> bool:
        if event_count[kind] >= args.max_events:
            return False
        event_count[kind] += 1
        return True

    if "blocks" in hook_names:
        block_path = dirs["logs"] / "basic_blocks.jsonl"

        def block_hook(ql_obj: Any, address: int, size: int) -> None:
            if maybe_log("blocks"):
                with block_path.open("a", encoding="utf-8") as f:
                    f.write(json.dumps({"address": hex(address), "size": size}) + "\n")

        try:
            ql.hook_block(block_hook)
            registered["registered"].append("hook_block")
        except Exception as exc:
            registered["failed"].append({"hook_block": f"{type(exc).__name__}: {exc}"})

    if "code" in hook_names:
        code_path = dirs["logs"] / "instructions.jsonl"

        def code_hook(ql_obj: Any, address: int, size: int) -> None:
            if maybe_log("code"):
                with code_path.open("a", encoding="utf-8") as f:
                    f.write(json.dumps({"address": hex(address), "size": size}) + "\n")

        try:
            ql.hook_code(code_hook)
            registered["registered"].append("hook_code")
        except Exception as exc:
            registered["failed"].append({"hook_code": f"{type(exc).__name__}: {exc}"})

    if "memory" in hook_names:
        def mem_invalid_hook(ql_obj: Any, access: int, address: int, size: int, value: int) -> bool:
            if maybe_log("memory"):
                ev.write(
                    "memory_invalid",
                    confidence="high",
                    access=access,
                    address=hex(address),
                    size=size,
                    value=hex(value) if isinstance(value, int) else value,
                )
            return False

        try:
            ql.hook_mem_invalid(mem_invalid_hook)
            registered["registered"].append("hook_mem_invalid")
        except Exception as exc:
            registered["failed"].append({"hook_mem_invalid": f"{type(exc).__name__}: {exc}"})

    if "syscalls" in hook_names or "files" in hook_names or "sockets" in hook_names:
        syscall_names = [
            "open",
            "openat",
            "close",
            "read",
            "write",
            "stat",
            "stat64",
            "lstat",
            "lstat64",
            "fstat",
            "access",
            "socket",
            "connect",
            "bind",
            "listen",
            "accept",
            "send",
            "sendto",
            "recv",
            "recvfrom",
            "ioctl",
            "futex",
            "clock_gettime",
        ]

        def make_syscall_hook(name: str):
            def syscall_hook(ql_obj: Any, *sys_args: Any) -> None:
                if not maybe_log("syscalls"):
                    return None
                details: dict[str, Any] = {
                    "syscall": name,
                    "args": [hex(a) if isinstance(a, int) else str(a) for a in sys_args],
                }
                if name == "open" and sys_args:
                    details["path"] = read_cstring_safe(ql_obj, sys_args[0])
                elif name == "openat" and len(sys_args) > 1:
                    details["path"] = read_cstring_safe(ql_obj, sys_args[1])
                ev.write("syscall_enter", confidence="medium", **details)
                return None

            return syscall_hook

        for name in syscall_names:
            try:
                ql.os.set_syscall(name, make_syscall_hook(name), QL_INTERCEPT.ENTER)
                registered["registered"].append(f"syscall:{name}")
            except Exception as exc:
                registered["failed"].append({f"syscall:{name}": f"{type(exc).__name__}: {exc}"})

    ev.write("hooks_registered", confidence="medium", hooks=registered)
    return registered


def add_fs_mappers(ql: Any, dirs: dict[str, Path], ev: JsonlEvidence) -> None:
    mappings = {
        "/data": dirs["data"],
        "/log": dirs["log"],
        "/identity": dirs["identity"],
        "/proc": dirs["proc"],
        "/sys": dirs["sys"],
        "/dev": dirs["dev"],
        "/run": dirs["run"],
        "/var/run": dirs["var_run"],
        "/var/volatile": dirs["var_volatile"],
        "/tmp": dirs["tmp"],
    }
    for guest, host in mappings.items():
        try:
            ql.add_fs_mapper(guest, str(host))
            ev.write(
                "fs_mapper_added",
                label="qiling_hooked_behavior",
                confidence="high",
                guest_path=guest,
                host_path=str(host),
                notes="Filesystem mapper is a lab overlay, not device runtime truth.",
            )
        except Exception as exc:
            ev.write(
                "fs_mapper_failed",
                label="qiling_hooked_behavior",
                confidence="medium",
                guest_path=guest,
                host_path=str(host),
                error=f"{type(exc).__name__}: {exc}",
            )


def run_qiling_target(args: argparse.Namespace, svc: dict[str, Any], ev: JsonlEvidence, dirs: dict[str, Path], seed_file: Path | None = None) -> dict[str, Any]:
    imports = qiling_imports()
    Qiling = imports["Qiling"]
    QL_VERBOSE = imports["QL_VERBOSE"]

    binary_guest = svc["binary"]
    binary_host = host_path(args.rootfs, binary_guest).resolve(strict=False)
    argv = [str(binary_host)] + list(args.extra_arg or [])
    verbose = getattr(QL_VERBOSE, "OFF", getattr(QL_VERBOSE, "DISABLED", 0))
    summary: dict[str, Any] = {
        "service": svc["name"],
        "binary": str(binary_host),
        "guest_binary": binary_guest,
        "argv": argv,
        "rootfs": str(args.rootfs),
        "seed_file": str(seed_file) if seed_file else None,
        "coverage": args.coverage,
        "debugger": args.debugger,
        "timeout": args.timeout,
    }
    ev.write("qiling_run_start", confidence="high", **summary)

    try:
        ql = Qiling(argv, str(args.rootfs), verbose=verbose, multithread=True)
        add_fs_mappers(ql, dirs, ev)
        register_hooks(ql, args, ev, dirs)

        if seed_file is not None:
            try:
                from qiling.extensions import pipe  # type: ignore

                stdin = pipe.SimpleInStream(0)
                stdin.write(seed_file.read_bytes())
                ql.os.stdin = stdin
                ev.write(
                    "stdin_seed_attached",
                    label="qiling_hooked_behavior",
                    confidence="medium",
                    seed_file=str(seed_file),
                    notes="Seed replay is a fuzz harness input, not observed device behavior.",
                )
            except Exception as exc:
                ev.write("stdin_seed_failed", label="qiling_hooked_behavior", confidence="medium", error=f"{type(exc).__name__}: {exc}")

        if args.debugger != "none":
            if args.debugger == "gdb":
                ql.debugger = f"gdb:127.0.0.1:{args.debug_port}"
            elif args.debugger == "idapro":
                ql.debugger = f"idapro:127.0.0.1:{args.debug_port}"
            elif args.debugger == "qdb":
                ql.debugger = True
                ev.write(
                    "debugger_qdb_requested_gdbserver_enabled",
                    confidence="medium",
                    notes="Official remote debugging support is gdbserver-compatible; qdb request is mapped to ql.debugger=True.",
                )
            ev.write("debugger_enabled", confidence="medium", debugger=args.debugger, port=args.debug_port)

        timeout_state = {"timed_out": False}

        def request_stop() -> None:
            timeout_state["timed_out"] = True
            try:
                ev.write("timeout_stop_requested", confidence="high", timeout=args.timeout)
                ql.emu_stop()
            except Exception as exc:
                ev.write("timeout_stop_failed", confidence="medium", error=f"{type(exc).__name__}: {exc}")

        timer = None
        if args.timeout > 0:
            timer = threading.Timer(args.timeout, request_stop)
            timer.daemon = True
            timer.start()
        else:
            ev.write(
                "timeout_disabled",
                confidence="medium",
                notes="timeout=0 disables the internal Qiling timer. Use this for interactive debugger sessions.",
            )
        try:
            if args.coverage == "drcov":
                try:
                    from qiling.extensions.coverage import utils as cov_utils  # type: ignore

                    coverage_file = dirs["coverage"] / f"{svc['name']}.drcov"
                    with cov_utils.collect_coverage(ql, "drcov", str(coverage_file)):
                        ql.run()
                    summary["coverage_file"] = str(coverage_file)
                except Exception as exc:
                    ev.write(
                        "coverage_drcov_failed",
                        confidence="medium",
                        error=f"{type(exc).__name__}: {exc}",
                        notes="Falling back to normal ql.run; basic block hook still records block events if enabled.",
                    )
                    ql.run()
            else:
                ql.run()
        finally:
            if timer is not None:
                timer.cancel()

        summary["status"] = "timeout" if timeout_state["timed_out"] else "completed"
        summary["exit_code"] = getattr(getattr(ql, "os", None), "exit_code", None)
        if timeout_state["timed_out"]:
            summary["error"] = f"Qiling run stopped after timeout={args.timeout}s"
            ev.write("qiling_run_timeout", confidence="high", **summary)
        else:
            ev.write("qiling_run_complete", confidence="medium", **summary)
    except Exception as exc:
        summary["status"] = "exception"
        summary["error"] = f"{type(exc).__name__}: {exc}"
        crash_path = dirs["crashes"] / f"{svc['name']}.exception.txt"
        write_text(crash_path, traceback.format_exc())
        summary["crash_report"] = str(crash_path)
        ev.write("qiling_run_exception", confidence="high", **summary)

    summary_path = dirs["target_dir"] / "run_summary.json"
    write_text(summary_path, json.dumps(summary, indent=2, sort_keys=True, default=str) + "\n")
    return summary


def build_default_seeds(args: argparse.Namespace, dirs: dict[str, Path]) -> Path:
    seed_dir = dirs["seeds"] / "default"
    build_script = SCRIPT_DIR / "build_seeds.py"
    subprocess.run(
        [
            sys.executable,
            str(build_script),
            "--rootfs",
            str(args.rootfs),
            "--qemu-lab",
            str(args.qemu_lab),
            "--out",
            str(seed_dir),
            "--include-evidence",
        ],
        check=True,
    )
    return seed_dir


def iter_seed_files(seed: Path) -> Iterable[Path]:
    if seed.is_file():
        yield seed
        return
    if not seed.exists():
        return
    for path in sorted(seed.rglob("*")):
        if path.is_file() and path.name != "seed_manifest.json":
            yield path


def fuzz_harness(args: argparse.Namespace, svc: dict[str, Any], ev: JsonlEvidence, dirs: dict[str, Path]) -> int:
    seed_root = Path(args.seed) if args.seed else build_default_seeds(args, dirs)
    seeds = list(iter_seed_files(seed_root))[: args.max_seeds]
    ev.write(
        "fuzz_harness_start",
        label="qiling_hooked_behavior",
        confidence="medium",
        seed_root=str(seed_root),
        seed_count=len(seeds),
        notes="Seed replay is a harness scaffold and does not claim the daemon normally consumes these inputs.",
    )
    results = []
    for idx, seed in enumerate(seeds, start=1):
        seed_dirs = prepare_run_dirs(args.qemu_lab, args.run_id, svc["name"], f"fuzz-harness/seed-{idx:03d}", args.evidence_root)
        seed_ev = JsonlEvidence(dirs["evidence_root"] / "observations.jsonl", args.run_id, svc["name"], "fuzz-harness")
        result = run_qiling_target(args, svc, seed_ev, seed_dirs, seed_file=seed)
        result["seed"] = str(seed)
        results.append(result)
    out = dirs["target_dir"] / "fuzz_harness_summary.json"
    write_text(out, json.dumps({"seed_root": str(seed_root), "results": results}, indent=2, sort_keys=True, default=str) + "\n")
    ev.write("fuzz_harness_complete", label="qiling_hooked_behavior", confidence="medium", output=str(out))
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="CHARX SEC-3100 V190 Qiling analysis runner.")
    parser.add_argument("--mode", choices=["matrix", "static-map", "instrumented-run", "fuzz-harness"], required=True)
    parser.add_argument("--service", default=None, help="Service name from service_matrix.json, or 'all' for static-map.")
    parser.add_argument("--rootfs", type=Path, default=DEFAULT_ROOTFS)
    parser.add_argument("--qemu-lab", type=Path, default=DEFAULT_QEMU_LAB)
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
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.mode == "matrix":
        return matrix_mode()

    matrix = load_matrix()
    services = service_map(matrix)
    if not args.service:
        raise SystemExit("--service is required for this mode")
    if args.service != "all" and args.service not in services:
        raise SystemExit(f"Unknown service {args.service!r}. Use --mode matrix to list services.")

    args.run_id = args.run_id or utc_run_id()
    args.rootfs = args.rootfs.resolve()
    args.qemu_lab = args.qemu_lab.resolve()

    selected = list(services.values()) if args.service == "all" else [services[args.service]]
    exit_code = 0
    for svc in selected:
        dirs = prepare_run_dirs(args.qemu_lab, args.run_id, svc["name"], args.mode, args.evidence_root)
        ev = JsonlEvidence(dirs["evidence_root"] / "observations.jsonl", args.run_id, svc["name"], args.mode)
        ev.write(
            "runner_invocation",
            confidence="high",
            firmware=matrix.get("firmware"),
            qiling_dir=str(QILING_DIR),
            rootfs=str(args.rootfs),
            service_tier=svc.get("tier"),
            service_binary=svc.get("binary"),
            argv=sys.argv,
        )
        import_qemu_baseline(args, ev, dirs)

        if args.mode == "static-map":
            static_map_service(args, svc, ev, dirs)
        elif args.mode == "instrumented-run":
            static_map_service(args, svc, ev, dirs)
            run_qiling_target(args, svc, ev, dirs)
        elif args.mode == "fuzz-harness":
            static_map_service(args, svc, ev, dirs)
            fuzz_harness(args, svc, ev, dirs)
        else:
            raise SystemExit(f"Unhandled mode: {args.mode}")

        print(dirs["evidence_root"])
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
