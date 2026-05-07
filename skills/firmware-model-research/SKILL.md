---
name: firmware-model-research
description: Use when Codex needs to research a firmware product, model, firmware version, vendor documentation, release notes, advisories, CVEs, CISA KEV status, protocol docs, or public writeups before emulation or CVE triage.
---

# Firmware Model Research

## Overview

Use this skill before emulation to prevent invented behavior. Every product behavior claim must be sourced, locally observed, or explicitly marked as an assumption.

## Required Superpowers

- Use `superpowers:systematic-debugging` when sources conflict or product/version identity is unclear.
- Use `superpowers:verification-before-completion` before claiming research is sufficient for emulation.
- Use `firmware-artifact-contract` before writing `model_research.json`.

## Memory Layer

Use `firmware-memory-layer` when `firmware-agent-workspace` exists and current artifacts are available for this phase. Run `suggest_memory.py` with the smallest relevant artifact set, read only suggestions marked `read_now`, and treat memory as a lead rather than behavior truth.

Write newly learned durable patterns only under `firmware-agent-workspace/drafts/`. Validate drafts before reuse and do not promote memory without validation.

## Inputs

- `firmware_manifest.json`.
- Product, model, vendor, version, firmware hash, and local strings when available.
- User-provided source URLs or local vendor documents.

## Workflow

1. Identify product, model, hardware revision, firmware version, vendor, and firmware hash confidence.
2. Search primary vendor sources first: product page, admin manual, service manual, release notes, download page, and security advisories.
3. Search official vulnerability sources: NVD/CVE, CISA KEV, vendor advisories, and standards or protocol documents.
4. Use public writeups, workshops, exploit notes, and GitHub repositories as leads only.
5. For every claim, record `claim_id`, `claim`, `source_type`, `source_url` or `source_artifact`, `retrieved_at`, `applies_to_product`, `applies_to_version`, `applies_to_firmware_hash`, `confidence`, and `behavior_claim_allowed`.
6. Separate documented behavior, locally observed behavior, assumptions, and contradictions.
7. Write `model_research.json`, `behavior_assumptions.md`, and `research_sources.md`.

## Outputs

- `model_research.json` with sourced claims and confidence.
- `behavior_assumptions.md` listing assumptions that must be validated during emulation.
- `research_sources.md` listing URLs, local docs, retrieval dates, and applicability notes.
All JSON outputs must include `schema_version` and the fields required by `firmware-artifact-contract`.

## Verification Gate

Research passes only when product identity and firmware/version confidence are explicit, at least one source or local artifact supports the identity, and contradictions are recorded.

If identity is unclear, write a blocker and do not let emulation rely on undocumented behavior.

## Safety

Operate only on firmware and runtimes the user is authorized to test. Keep destructive probes disabled by default; record runtime modifications; prefer local evidence and redacted summaries; use exact dates and versions in vulnerability reports; do not install tools without explicit user approval.

Do not commit firmware, private vendor files, secrets, API keys, cookies, or full proprietary dumps into research notes. Do not treat public writeups as runtime truth.

Use exact dates for current-source claims.

## Common Mistakes

- Using a CVE for a neighboring model without checking version applicability.
- Treating a blog post as proof that a service exists in this firmware.
- Omitting firmware hash or version confidence.
- Resolving contradictory sources silently.
