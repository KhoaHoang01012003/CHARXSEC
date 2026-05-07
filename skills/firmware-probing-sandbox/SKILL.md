---
name: firmware-probing-sandbox
description: Use when Codex needs to generate firmware pentest payloads, API clients, parsers, replay scripts, corpus files, or local proof harnesses from verified context without touching live firmware by default.
---

# Firmware Probing Sandbox

## Overview

Use this skill to generate probes in a Python sandbox with no network by default. Sandbox output helps explore hypotheses, but it is `sandbox_generated` and must keep `behavior_claim_allowed=false` until separate live runtime evidence verifies it.

## Required Superpowers

- Use `superpowers:brainstorming` before designing new probes, harnesses, payload families, or behavior changes.
- Use `superpowers:systematic-debugging` when generated probes fail locally, parsers disagree, fixtures are malformed, or sandbox behavior is inconsistent.
- Use `superpowers:verification-before-completion` before claiming probe generation succeeded.
- Use `firmware-artifact-contract` before writing `probe_plan.json`, `sandbox_observations.jsonl`, or finding hypotheses.

## Inputs

- Current hypothesis from `skill_context.json`, `code_browser_findings.jsonl`, `observations.jsonl`, or `debug_observations.jsonl`.
- Target API, file format, parser, protocol, endpoint, or replay surface.
- Runtime limitations, safety constraints, and user authorization boundaries.

## Workflow

1. Confirm scope and safety boundaries before generating probes.
2. Write `probe_plan.json` with `schema_version`, target, payload families, safety constraints, and `sandbox_network=disabled` unless explicitly authorized.
3. Detect available local tools and libraries; record unavailable tools as `missing_tool`.
4. Generate deterministic payloads, parsers, corpus files, API clients, and replay scripts for local execution.
5. Keep network access disabled and do not call live runtime unless explicitly configured by the user.
6. Run local probes against fixtures, parsers, or offline harnesses when possible.
7. Record `sandbox_generated` observations in `sandbox_observations.jsonl` with `behavior_claim_allowed=false`.
8. Promote only well-scoped hypotheses to `findings.jsonl`; do not claim CVE or runtime impact from sandbox output.
9. Store generated artifacts and logs under local evidence paths and summarize only redacted, high-signal results.

## Outputs

- `probe_plan.json` with planned payloads, constraints, and sandbox network mode.
- Generated scripts, testcases, corpus, and parser fixtures in local evidence directories.
- `sandbox_observations.jsonl` with `sandbox_generated` observations and `behavior_claim_allowed=false`.
- Candidate `findings.jsonl` records marked as hypotheses, not verified findings.
- `known_limitations.md` with unsupported formats, `missing_tool` entries, skipped probes, and required live verification.

## Verification Gate

Probe generation passes only when generated probes run locally or a blocker explains why they cannot; destructive actions require explicit user authorization and must remain disabled by default.

## Safety

Operate only on firmware and runtimes the user is authorized to test. Keep destructive probes disabled by default; record runtime modifications; prefer local evidence and redacted summaries; use exact dates and versions in vulnerability reports; do not install tools without explicit user approval.

Do not commit firmware, generated exploit payloads intended for unauthorized targets, runtime rootfs, credentials, cookies, tokens, private keys, certificates, or identity material. Keep generated artifacts in local evidence directories and do not enable live network calls without explicit user approval.

## Common Mistakes

- Treating sandbox output as firmware runtime truth.
- Calling live runtime from the sandbox without explicit authorization.
- Generating destructive requests by default.
- Writing broad fuzzers before defining a narrow target and stop condition.
- Omitting `missing_tool` records, which hides sandbox coverage gaps.
