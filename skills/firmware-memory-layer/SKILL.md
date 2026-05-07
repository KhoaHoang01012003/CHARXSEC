---
name: firmware-memory-layer
description: Use when Codex needs to suggest, read, draft, validate, or promote reusable product, service, tool, runtime, emulation, hook, debugger, probe, or CVE verification memories for firmware pentest workflows.
---

# Firmware Memory Layer

## Overview

Use this supporting skill to reuse durable firmware pentest lessons without loading large memory folders or trusting unreviewed notes. Memory is advisory: current artifacts, live runtime evidence, and verifier gates always win.

## Required Superpowers

- Use `superpowers:systematic-debugging` when memory contradicts current artifacts or runtime evidence.
- Use `superpowers:verification-before-completion` before claiming a memory draft, suggestion, or promotion is valid.
- Use `superpowers:writing-skills` plus `skill-creator` when changing this skill or memory format.

## Inputs

- `firmware-agent-workspace`.
- Firmware artifacts such as `model_research.json`, `rootfs_profile.json`, `service_graph.json`, `runtime_profile.json`, `observations.jsonl`, and `verifier_report.json`.
- Optional current hypothesis, target service, runtime profile, or blocker.

## Workflow

1. Run `suggest_memory.py` with only the artifacts available for the current phase.
2. Read only suggestions marked `read_now`.
3. Treat memory as a lead, not behavior truth.
4. Write new reusable lessons only under `firmware-agent-workspace/drafts/`.
5. Validate drafts with `validate_memory.py`.
6. Promote drafts with `promote_memory.py` only after validation passes.
7. Re-run suggestion after promotion when the current task benefits from the new memory.

## Memory Types

- `product`: vendor, model, firmware version, or product-line behavior.
- `service`: reusable service or protocol behavior across products.
- `tool`: runtime, debugger, hooker, code browser, extraction, or verification tool behavior.

## Outputs

- `memory_suggestions.json`.
- Validated memory drafts under `firmware-agent-workspace/drafts/`.
- Promoted Markdown memory files under product, service, or tool folders.
- Updated `firmware-agent-workspace/memory-index.json`.

## Verification Gate

Memory work passes only when helper scripts exit 0, generated JSON is valid, promoted memory validates, and no secret-like or raw evidence material is present.

## Safety

Operate only on firmware and runtimes the user is authorized to test. Keep destructive probes disabled by default; record runtime modifications; prefer local evidence and redacted summaries; use exact dates and versions in vulnerability reports; do not install tools without explicit user approval.

Do not commit firmware, rootfs dumps, private configs, credentials, cookies, tokens, private keys, certificates, raw traces, packet captures, debugger transcripts, memory dumps, identity material, or exploit payloads for unauthorized targets.

## Common Mistakes

- Reading every memory file instead of using suggestions.
- Treating product-specific memory as generic service truth.
- Promoting a draft that lacks source artifacts or exact verification dates.
- Storing raw traces or secrets in memory.
- Letting stale memory override current runtime evidence.
