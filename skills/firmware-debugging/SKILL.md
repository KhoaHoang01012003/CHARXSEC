---
name: firmware-debugging
description: Use when Codex needs to attach or launch a debugger for firmware services, crashes, hangs, tracebacks, qemu-user/qemu-system targets, gdbserver, QEMU gdbstub, GDB/gdb-multiarch, Ghidra Debugger notes, or Qiling debugger instrumentation.
---

# Firmware Debugging

## Overview

Use this skill to attach or launch a debugger with correct host-vs-guest semantics. Debugger evidence must state what was actually observed and whether the action was intrusive.

## Required Superpowers

- Use `superpowers:systematic-debugging` for crash loops, missed breakpoints, wrong architecture, wrong process, symbol mismatch, or debugger-induced failures.
- Use `superpowers:verification-before-completion` before claiming the debugger captured behavior.
- Use `firmware-artifact-contract` before writing `debug_plan.json`, `gdb_commands.gdb`, `gdb_transcript.txt`, or `debug_observations.jsonl`.

## Inputs

- `runtime_profile.json`.
- `service_readiness.json`.
- Target process, binary, PID, port, crash, hang, traceback, or function hypothesis.
- Existing hook evidence such as `observations.jsonl`, `traceback_key_lines.txt`, or `syscall_summary.txt`.

## Workflow

1. Identify architecture, runtime profile, target process, and whether debugging can be non-intrusive.
2. Write `debug_plan.json` with attach mode, target process, expected breakpoint or observation, and intrusive actions.
3. Detect GDB, gdb-multiarch, gdbserver, QEMU user/system gdbstub, and Qiling debugger availability; record unavailable tools as `missing_tool`.
4. For `qemu-user`, distinguish host QEMU attach from guest breakpoints.
5. Prefer restart-mode QEMU user/system gdbstub or gdbserver when guest breakpoints are required and service restart is safe.
6. Use host QEMU attach only when host-level behavior is the intended evidence.
7. Use Qiling debugger as separate target instrumentation, not proof of active runtime behavior.
8. Generate `gdb_commands.gdb`, capture `gdb_transcript.txt`, and write `debug_observations.jsonl`.
9. Mark observations `behavior_claim_allowed=true` only when the transcript proves live runtime behavior or a verified debugger observation.

## Outputs

- `debug_plan.json` with `schema_version`, target process, attach mode, expected evidence, and intrusive actions.
- `gdb_commands.gdb` with reproducible commands.
- `gdb_transcript.txt` stored as local evidence.
- `debug_observations.jsonl` with labels such as `observed_runtime_live_debugger`, `observed_runtime_qemu`, `observed_qiling_target`, `blocked`, or `unverified`.
- `known_limitations.md` with symbol gaps, attach failures, and `missing_tool` records.

## Verification Gate

Debugging passes only when the transcript or blocker explains what the debugger actually observed. For `qemu-user`, the report must state whether evidence came from host QEMU attach or guest breakpoints through QEMU user/system gdbstub, gdbserver, or GDB.

## Safety

Do not commit firmware, runtime rootfs, raw debugger transcripts, memory dumps, credentials, cookies, tokens, private keys, certificates, or identity material. Make intrusive behavior explicit before stopping, restarting, pausing, or modifying a service.

## Common Mistakes

- Claiming guest application behavior from host QEMU attach without proof.
- Setting breakpoints in the wrong architecture or binary mapping.
- Continuing after a missed breakpoint without systematic debugging.
- Treating Qiling debugger output as active runtime truth.
- Hiding intrusive service restarts from evidence notes.
