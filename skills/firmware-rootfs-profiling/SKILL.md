---
name: firmware-rootfs-profiling
description: Use when Codex needs to profile an extracted firmware rootfs, architecture, libc, init system, services, ports, web roots, API routes, configs, binary metadata, secrets indicators, or attack-surface ranking before emulation.
---

# Firmware Rootfs Profiling

## Overview

Use this skill after extraction and model research to create `rootfs_profile.json`, `service_graph.json`, and a compact `skill_context.json` for later LLM work.

## Required Superpowers

- Use `superpowers:systematic-debugging` when rootfs layout, architecture, init system, or service ownership is inconsistent.
- Use `superpowers:verification-before-completion` before claiming profiling is complete.
- Use `firmware-artifact-contract` before writing JSON artifacts.

## Memory Layer

Use `firmware-memory-layer` when `firmware-agent-workspace` exists and current artifacts are available for this phase. Run `suggest_memory.py` with the smallest relevant artifact set, read only suggestions marked `read_now`, and treat memory as a lead rather than behavior truth.

Write newly learned durable patterns only under `firmware-agent-workspace/drafts/`. Validate drafts before reuse and do not promote memory without validation.

## Inputs

- Rootfs candidate path from `firmware_manifest.json`.
- `model_research.json`.
- Scope hint such as web/API, update, network, auth, or full baseline.

## Workflow

1. Identify architecture, endianness, libc, kernel hints, init system, package managers, and writable mount assumptions.
2. Inventory init scripts, systemd units, inetd configs, nginx/httpd configs, route definitions, web assets, helper scripts, and privileged binaries.
3. Map service candidates to binaries, process names, ports, configs, logs, IPC, and data directories.
4. Use CodeQL, Semgrep, and Joern only when supported source languages are present.
5. Use binary-map, `file`, `readelf`, `strings`, symbol/import/export analysis, and Ghidra/rizin hints for stripped ELF or proprietary modules.
6. Record secrets indicators without copying secrets into summaries.
7. Rank targets by network exposure, privilege, parser complexity, update/config reachability, auth boundary, advisory relevance, and runtime feasibility.
8. Write `rootfs_profile.json`, `service_graph.json`, `skill_context.json`, and `interesting_targets.json`.

## Outputs

- `rootfs_profile.json` with architecture, libc/init hints, package/config/service inventory, and warnings.
- `service_graph.json` with service names, binaries, process patterns, ports, logs, dependencies, and readiness classification candidates.
- `skill_context.json` with compact high-signal context for LLM use.
- `interesting_targets.json` with ranked targets and reasons.
All JSON outputs must include `schema_version` and the fields required by `firmware-artifact-contract`.

## Verification Gate

Profiling passes only when arch, libc/init hint, service candidates, and attack-surface ranking exist, or a structured blocker explains why profiling could not continue.

Static profile observations must set `behavior_claim_allowed=false`.

## Safety

Operate only on firmware and runtimes the user is authorized to test. Keep destructive probes disabled by default; record runtime modifications; prefer local evidence and redacted summaries; use exact dates and versions in vulnerability reports; do not install tools without explicit user approval.

Do not commit firmware, extracted rootfs, private configs, keys, certs, tokens, or raw proprietary code. Keep snippets small and source-attributed.

## Common Mistakes

- Treating CodeQL as a binary firmware analyzer.
- Copying secrets from config files into reports.
- Missing init scripts outside systemd.
- Ranking targets without considering runtime feasibility.
