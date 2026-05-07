---
name: firmware-service-emulating
description: Use when Codex needs to emulate firmware services, choose qemu-user/qemu-system/native-container/device-ssh/static-only runtime, start services, classify expected services, run process/port/log/API readiness checks, or block CVE hunting on HTTP 500 and service failures.
---

# Firmware Service Emulating

## Overview

Use this skill to start the highest-fidelity practical runtime and prove readiness before pentesting. A process that starts is not enough: required services, ports, logs, and API smoke tests must pass or produce blockers.

## Required Superpowers

- Use `superpowers:systematic-debugging` immediately for HTTP 500, crash, missing dependency, auth bootstrap failure, service loop, or inconsistent readiness.
- Use `superpowers:verification-before-completion` before claiming the runtime is ready.
- Use `firmware-artifact-contract` before writing `runtime_profile.json`, `service_readiness.json`, or `api_smoke_results.json`.

## Inputs

- `firmware_manifest.json`.
- `model_research.json`.
- `rootfs_profile.json`.
- `service_graph.json`.
- User-selected pentest scope.

## Workflow

1. Select runtime profile: `qemu-user`, `qemu-system`, `native-container`, `device-ssh`, or `static-only`.
2. Use `rootfs_rw` for active runtime when available and keep `rootfs_ro` as baseline.
3. Classify expected services as `required`, `optional`, `hardware_blocked`, `mocked`, or `known_broken`.
4. Start only the services required by the selected scope unless the user asks for full stack.
5. Check required processes, ports, logs, and API/HTTP smoke tests.
6. Treat unexplained HTTP 500, repeated traceback, crash, missing dependency, or service loop as blockers.
7. Write `runtime_profile.json`, `service_readiness.json`, `api_smoke_results.json`, `runtime_warnings.json`, and `known_limitations.md`.
8. If blocked, write `emulation_blocker.json` and switch to `superpowers:systematic-debugging` instead of CVE hunting.

## Outputs

- `runtime_profile.json` with selected runtime, rootfs mode, paths, tool availability, warnings, and limitations.
- `service_readiness.json` with service classifications, expected/observed process patterns, ports, logs, smoke tests, readiness, and blocker IDs.
- `api_smoke_results.json` with controlled HTTP/API smoke results.
- `runtime_warnings.json` and `known_limitations.md`.
- `emulation_blocker.json` when readiness fails.
All JSON outputs must include `schema_version` and the fields required by `firmware-artifact-contract`. Runtime observations may set `behavior_claim_allowed=true` only for behavior observed through a live runtime readiness or smoke test artifact.

## Verification Gate

Runtime readiness passes only when `service_readiness.json` validates, every `required` service is `ready`, required API smoke tests pass, and there is no unexplained HTTP 500 or repeated traceback.

The only valid final states are `ready_for_pentest=true` or a blocker with root-cause work queued.

## Safety

Operate only on firmware and runtimes the user is authorized to test. Keep destructive probes disabled by default; record runtime modifications; prefer local evidence and redacted summaries; use exact dates and versions in vulnerability reports; do not install tools without explicit user approval.

Do not commit firmware, runtime rootfs, logs, packet captures, credentials, private keys, certs, cookies, tokens, or identity material. Record runtime modifications and keep destructive endpoints disabled by default.

## Common Mistakes

- Calling emulation ready because one process started.
- Ignoring HTTP 500 in API smoke tests.
- Treating mocked or hardware-blocked services as fully faithful behavior.
- Using static-only analysis to claim runtime behavior.
- Continuing to CVE hunting before readiness passes.
