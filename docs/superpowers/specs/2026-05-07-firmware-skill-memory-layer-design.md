# Firmware Skill Memory Layer Design

## Status

Approved design direction: add a strong hybrid memory layer inspired by browser-harness while keeping the existing firmware auto-pentest phase skills stable.

This document is a design spec only. It does not scaffold or install the memory layer yet.

## Goal

Add a reusable "field memory" layer to the firmware auto-pentest skill suite so an LLM can reuse durable lessons learned from previous firmware work without re-discovering the same product quirks, service layouts, emulation blockers, debugger tricks, or CVE verification patterns.

The memory layer must remain dynamic:

- it must work for many firmware families, not only the CHARX prototype;
- it must use artifacts such as `model_research.json`, `rootfs_profile.json`, `service_graph.json`, `runtime_profile.json`, observations, and verifier reports to discover relevant memories;
- it must avoid loading large memory folders into context;
- it must write new knowledge as drafts first, then validate and promote only safe, reusable, evidence-backed memory.

## Source Pattern

The design borrows the useful shape from `browser-use/browser-harness`:

- thin core instructions;
- helper functions that do deterministic work;
- domain-specific skill files discovered only when relevant;
- agent-editable workspace for durable field notes;
- learned patterns are saved as reusable skills instead of being rediscovered every session.

References:

- Browser Harness repository: https://github.com/browser-use/browser-harness
- Browser Harness `SKILL.md`: https://raw.githubusercontent.com/browser-use/browser-harness/main/SKILL.md
- Browser Harness helper pattern: https://raw.githubusercontent.com/browser-use/browser-harness/main/src/browser_harness/helpers.py

## Non-Goals

- Do not replace the existing nine phase skills.
- Do not create a monolithic orchestrator skill.
- Do not let the LLM directly promote memory into trusted skills without validation.
- Do not store firmware images, rootfs dumps, private configs, secrets, raw traces, packet captures, debugger transcripts, or exploit payloads in memory skill files.
- Do not hard-code CHARX paths, ports, credentials, or service names into generic memory logic.
- Do not install external tools as part of memory suggestion or validation without explicit operator approval.

## Architecture

Add one supporting skill plus one repo-local workspace:

```text
skills/
  firmware-memory-layer/
    SKILL.md
    agents/openai.yaml
    references/
      memory_file_format.md
      memory_workflow.md
      schemas/
        memory_index.schema.json
        memory_suggestion.schema.json
        memory_draft.schema.json
    scripts/
      suggest_memory.py
      validate_memory.py
      promote_memory.py

firmware-agent-workspace/
  agent_helpers.py
  memory-index.json
  product-skills/
    <vendor>/<model>/<topic>.md
  service-skills/
    <service-or-stack>/<topic>.md
  tool-skills/
    <tool-or-runtime>/<topic>.md
  drafts/
    <timestamp>-<topic>.md
```

The existing phase skills should receive only small integration notes. They should not duplicate memory-layer logic.

## Memory Types

### Product Memory

Use product memory for vendor/model/version behavior that is too specific for generic service skills.

Examples:

- firmware boot order for a specific model;
- model-specific web management behavior;
- known hardware-blocked services for a product line;
- version-specific update or API behavior.

Path pattern:

```text
firmware-agent-workspace/product-skills/<vendor>/<model>/<topic>.md
```

### Service Memory

Use service memory for reusable behavior across products.

Examples:

- RAUC update bundle flow;
- BusyBox httpd CGI layout;
- lighttpd route discovery;
- D-Bus service enumeration;
- MQTT broker/client interaction patterns;
- web API smoke-test patterns.

Path pattern:

```text
firmware-agent-workspace/service-skills/<service-or-stack>/<topic>.md
```

### Tool And Runtime Memory

Use tool/runtime memory for repeatable tool gotchas and workflows.

Examples:

- qemu-user service start blockers;
- qemu-system gdbstub attach patterns;
- gdb-multiarch setup notes;
- strace/tcpdump correlation pattern;
- Frida attach constraints;
- CodeQL/Semgrep/Joern support boundaries for firmware artifacts.

Path pattern:

```text
firmware-agent-workspace/tool-skills/<tool-or-runtime>/<topic>.md
```

## Memory File Format

Each promoted memory file is Markdown with YAML frontmatter:

```markdown
---
memory_schema_version: 1.0.0
memory_type: service
title: RAUC Update Bundle Flow
status: active
tags: [rauc, update, bundle]
applies_to:
  vendors: []
  models: []
  firmware_versions: []
  services: [rauc]
  runtimes: []
  tools: [rauc, unsquashfs]
evidence:
  source_artifacts: [model_research.json, service_graph.json]
  verified_on: 2026-05-07
  firmware_hashes: []
artifact_sensitivity: local_metadata
---

# RAUC Update Bundle Flow

## Use When

Use this memory when the rootfs or firmware manifest shows RAUC bundle metadata or `.raucb` update packages.

## Durable Pattern

Describe the reusable behavior or workflow.

## Evidence

List local artifacts, public references, or reproduction commands that support the pattern.

## Limits

State what this memory does not prove and when it should not be used.

## Safety

State sensitive evidence that must remain local and redacted.
```

Required memory headings:

- `## Use When`
- `## Durable Pattern`
- `## Evidence`
- `## Limits`
- `## Safety`

## Draft Rules

The LLM may create memory drafts, but drafts are not trusted memory.

Drafts live under:

```text
firmware-agent-workspace/drafts/
```

Drafts must include:

- memory type: `product`, `service`, or `tool`;
- product/service/tool scope;
- exact date of observation;
- source artifact paths or public URLs;
- firmware hash or explicit reason it is unknown;
- sensitivity label;
- limitations;
- redacted summaries only.

Drafts must not include:

- credentials, cookies, tokens, private keys, certificates, or identity material;
- raw firmware, rootfs dumps, binary dumps, memory dumps, pcaps, raw logs, or raw debugger transcripts;
- exploit payloads for unauthorized targets;
- unsupported runtime behavior claims.

## Scripts

### suggest_memory.py

Purpose: read firmware artifacts and suggest relevant memory files without loading them into the LLM context.

Inputs:

- `--workspace firmware-agent-workspace`
- optional `--model-research model_research.json`
- optional `--rootfs-profile rootfs_profile.json`
- optional `--service-graph service_graph.json`
- optional `--runtime-profile runtime_profile.json`
- optional `--observations observations.jsonl`
- optional `--verifier-report verifier_report.json`

Output:

- `memory_suggestions.json`

Each suggestion includes:

- `memory_path`
- `memory_type`
- `score`
- `matched_terms`
- `matched_artifacts`
- `reason`
- `load_recommendation`: `read_now`, `read_if_blocked`, or `skip`

The script should rank by vendor/model, service names, runtime profile, tools, filenames, route names, error signatures, evidence labels, and CWE or CVE context when available.

### validate_memory.py

Purpose: validate drafts and promoted memory files before they are trusted.

Checks:

- required frontmatter fields exist;
- required headings exist;
- `artifact_sensitivity` is allowed;
- date fields are exact;
- source artifacts or source URLs exist;
- memory does not contain obvious secret patterns;
- memory does not contain raw evidence markers such as private keys, certificates, cookies, bearer tokens, or large hex/base64 blocks;
- runtime behavior claims are backed by live runtime or verified evidence labels when claimed as behavior truth.

### promote_memory.py

Purpose: promote a validated draft into product, service, or tool memory.

Rules:

- validation must pass first;
- destination path must match `memory_type`;
- existing memory must not be overwritten unless `--update-existing` is explicit;
- promotion must update `memory-index.json`;
- promoted memory keeps source artifact references but not raw evidence.

## Memory Index

`memory-index.json` is a compact machine-readable index generated from promoted memory frontmatter.

It should include:

- schema version;
- generated timestamp;
- workspace root;
- memory records with path, type, title, status, tags, applies-to fields, evidence summary, sensitivity, and last verified date.

The index lets the LLM or helper choose relevant memory without reading every Markdown file.

## Phase Skill Integration

Keep existing skills stable by adding a small "Memory Layer" section to each relevant skill.

Recommended integration:

- `firmware-model-research`: suggest product memories after product/model/version confidence is known.
- `firmware-rootfs-profiling`: suggest service and tool memories after service candidates and architecture are known.
- `firmware-service-emulating`: suggest runtime and service memories before declaring blockers or writing emulation workarounds.
- `firmware-code-browsing`: suggest service/tool memories for source languages, configs, reverse-engineering queues, and route patterns.
- `firmware-runtime-hooking`: suggest runtime/tool memories for capture lanes and known trace correlation patterns.
- `firmware-debugging`: suggest runtime/tool memories for attach mode, gdbstub, gdbserver, host-vs-guest semantics, and symbol gaps.
- `firmware-probing-sandbox`: suggest service memories for protocol/API payload generation patterns.
- `firmware-cve-verification`: suggest product/service memories for known issue patterns, duplicate checks, and affected-version boundaries.

Each phase skill should say:

1. run memory suggestion when a relevant workspace exists;
2. read only `read_now` suggestions;
3. write new knowledge only as drafts;
4. do not promote memory without validation.

## LLM Brain Loop With Memory

The firmware brain loop becomes:

1. Extract firmware.
2. Research model and firmware behavior.
3. Suggest product memory.
4. Profile rootfs and service graph.
5. Suggest service and tool memory.
6. Emulate with readiness gate.
7. Use relevant memories for known blockers and smoke-test patterns.
8. Browse code and form one hypothesis.
9. Probe, hook, debug, and verify.
10. Capture new durable lessons as drafts.
11. Promote only validated, safe, reusable memory.

The LLM may use memory as a guide. Memory does not override current artifacts, live runtime evidence, or verifier gates.

## Safety And Authorization

All memory-layer operations inherit the firmware suite safety rules:

- operate only on firmware and runtimes the user is authorized to test;
- do not exfiltrate secrets, keys, identity material, firmware images, rootfs dumps, raw pcaps, or runtime dumps;
- keep destructive probes disabled by default;
- record runtime modifications;
- prefer local evidence and redacted summaries;
- use exact dates and versions in vulnerability reports;
- do not install tools without explicit user approval.

Additional memory-specific rules:

- redaction failure blocks promotion;
- missing evidence blocks promotion;
- product-specific memory must not be generalized silently;
- public writeups can be leads but not runtime truth;
- stale memory must be marked `deprecated` or `needs_revalidation` when contradicted by newer evidence.

## Testing Strategy

Use deterministic tests before implementation is considered complete:

- validator accepts a valid product memory draft;
- validator accepts a valid service memory file;
- validator rejects a draft containing secret-like material;
- validator rejects a draft without evidence source;
- validator rejects a behavior claim without live or verified evidence;
- suggestion helper returns only relevant memories for a fixture rootfs/service graph;
- promotion moves a draft to the correct memory folder and updates `memory-index.json`;
- phase skill tests confirm each skill references the memory layer without losing existing guardrails.

## Acceptance Criteria

The memory layer is acceptable when:

- `firmware-memory-layer` is discoverable as a supporting skill;
- memory helper scripts are deterministic and tested;
- memory files have a stable, validated format;
- suggestions are artifact-driven and do not hard-code CHARX;
- suggestions are compact enough for LLM use;
- drafts cannot be promoted when they contain secrets, raw evidence, missing evidence, or unsupported behavior claims;
- existing nine phase skills continue to pass their current tests;
- existing artifact contract behavior remains backward compatible;
- raw firmware, rootfs, traces, pcaps, debugger transcripts, credentials, and exploit payloads remain local and are not committed;
- memory improves token efficiency by loading only relevant product/service/tool knowledge.

## Implementation Notes

Implementation should happen as a new wave after the current Wave 1-3 skill suite:

1. add memory-layer tests and fixtures first;
2. add `firmware-memory-layer` skill and memory schemas;
3. add `suggest_memory.py`, `validate_memory.py`, and `promote_memory.py`;
4. add a minimal `firmware-agent-workspace` with safe non-template examples only if tests require them;
5. add small memory integration sections to existing phase skills;
6. run the full firmware skill suite tests plus memory-layer tests.

This wave should not install the skills into `$CODEX_HOME/skills`. Installation remains a separate operator action.

## Self-Review

Template scan: no scaffold requirements are left open.

Internal consistency: the design keeps the existing phase skills as the primary workflow and adds memory as a supporting layer only.

Scope check: this is one implementation wave focused on memory suggestion, draft validation, and safe promotion.

Ambiguity check: memory promotion is explicit and validation-gated; drafts are not trusted memory.
