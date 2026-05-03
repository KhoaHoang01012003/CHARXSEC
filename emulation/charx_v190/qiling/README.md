# CHARX SEC-3100 V190 Qiling Lab

This lab is an analysis, fuzzing and instrumentation companion for the existing QEMU/chroot service replay. It is not a replacement for the full-service QEMU lab.

Core rule: Qiling evidence is labeled `observed_qiling_target`. It is useful for tracing, hooks, debugger sessions, coverage and fuzz harnesses, but it is not behavior truth for the complete device unless it matches QEMU/runtime evidence.

## Quick Start

From Windows PowerShell:

```powershell
.\emulation\charx_v190\charx-qiling.cmd bootstrap
.\emulation\charx_v190\charx-qiling.cmd matrix
.\emulation\charx_v190\charx-qiling.cmd static-map --service charx-website
.\emulation\charx_v190\charx-qiling.cmd run --service charx-website --timeout 15 --coverage drcov
```

From WSL Debian:

```bash
/mnt/d/CHARXSEC/emulation/charx_v190/qiling/scripts/qiling_lab.sh bootstrap
/mnt/d/CHARXSEC/emulation/charx_v190/qiling/scripts/qiling_lab.sh matrix
/mnt/d/CHARXSEC/emulation/charx_v190/qiling/scripts/qiling_lab.sh static-map --service charx-website
/mnt/d/CHARXSEC/emulation/charx_v190/qiling/scripts/qiling_lab.sh run --service charx-website --timeout 15 --coverage drcov
```

Evidence is written under:

```text
/home/khoa/charx_labs/charx_v190/evidence/<run_id>/
```

The Qiling virtualenv is created under:

```text
/home/khoa/charx_labs/charx_v190/qiling_venv/
```

If the WSL lab directory is root-owned and not writable by the current user, the scripts automatically fall back to:

```text
$HOME/.charx_qiling_v190/qiling_venv/
emulation/charx_v190/qiling/evidence/<run_id>/
```

## Modes

- `static-map`: inventory ELF metadata, dynamic dependencies, configs, route hints and strings without executing firmware code.
- `instrumented-run`: run one service under Qiling with syscall, filesystem, socket, block, memory and optional debugger/coverage hooks.
- `fuzz-harness`: replay seed files into a target with Qiling instrumentation and crash capture. It is a harness scaffold, not a claim that the daemon normally consumes stdin.

## Service Tiers

- Tier A: `charx-website`, `charx-system-config-manager`.
- Tier B: `charx-jupicore`, `charx-ocpp16-agent`, `charx-modbus-agent`, `charx-modbus-server`, `charx-loadmanagement`, `charx-update-agent`.
- Tier C: `charx-controller-agent`, `charx-system-monitor`.

Tier C targets are experimental because their behavior depends on CAN, QCA/HomePlug, modem, TPM/certificates, SECC and other hardware/runtime material.

## Debugger And Coverage

Qiling supports GDB-compatible remote debugging by assigning `ql.debugger`, and supports drcov coverage through `qiling.extensions.coverage`. The runner exposes those as:

```bash
qiling_lab.sh run --service charx-website --debugger gdb --debug-port 9999
qiling_lab.sh run --service charx-website --coverage drcov --timeout 30
```

The official Qiling documentation for hooks, debugger and coverage should be used as the API source of truth:

- https://docs.qiling.io/en/latest/hook/
- https://docs.qiling.io/en/latest/debugger/
- https://docs.qiling.io/en/latest/coverage/

## Fidelity Rules

- Do not use Qiling-only output to claim full firmware behavior.
- Do not patch original firmware binaries.
- If a hook changes behavior, label it `qiling_hooked_behavior`.
- If a dependency is mocked, label it `mocked_behavior` and use the existing mock provenance policy.
- QEMU/chroot remains the baseline for WBM/API/service behavior.
