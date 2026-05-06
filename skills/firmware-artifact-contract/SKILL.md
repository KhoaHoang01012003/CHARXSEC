---
name: firmware-artifact-contract
description: Use when firmware pentest skills need to create, validate, or consume shared evidence artifacts, schema_version fields, observation labels, artifact sensitivity, service readiness records, or blocker reports.
---

# Firmware Artifact Contract

## Overview

Use this supporting skill before writing or trusting artifacts shared by the firmware auto-pentest skill suite. The contract keeps phase skills interoperable and prevents unverified or sensitive evidence from leaking into reports.

## Required Superpowers

- Use `superpowers:systematic-debugging` when validation fails unexpectedly.
- Use `superpowers:verification-before-completion` before claiming an artifact is valid.

## Contract Rules

Every JSON artifact must include `schema_version`, `generated_at`, `generated_by`, `source_inputs`, `warnings`, and `errors`.

Every observation record must include `schema_version`, `timestamp_utc`, `component`, `event_type`, `label`, `behavior_claim_allowed`, `source_artifact`, `risk_notes`, and `artifact_sensitivity`.

Allowed `artifact_sensitivity` values are `public_reference`, `local_metadata`, `local_sensitive`, `secret_material`, and `firmware_proprietary`.

Do not print, commit, upload, or summarize `secret_material` or raw `firmware_proprietary` data. Summaries for `local_sensitive` artifacts must be redacted first.

## Wave 2 Runtime Truth Rules

Static code browser output, Qiling-only output, sandbox output, mocked behavior, and planned actions must set `behavior_claim_allowed=false`.

Only `observed_runtime_qemu`, `observed_runtime_live_hook`, `observed_runtime_live_debugger`, and `verified` observations may set `behavior_claim_allowed=true`, and only when the source artifact proves the target workload was observed.

Raw traces, packet captures, debugger transcripts, browser exports, and proprietary snippets must stay in ignored local evidence directories. LLM-facing summaries must be compact, redacted, and source-attributed.

## Validation

Run the bundled validator before trusting Wave 1 artifacts:

```powershell
python skills/firmware-artifact-contract/scripts/validate_artifact.py --artifact-type service_readiness --schema-dir skills/firmware-artifact-contract/references/schemas path/to/service_readiness.json
```

The validator is dependency-free and checks required fields, enums, and readiness blockers that matter for LLM-controlled firmware pentest workflows.

## Evidence Labels

Use these labels exactly:

- `planned_static_analysis`
- `planned_runtime_live_hook`
- `planned_runtime_live_debugger`
- `observed_static_artifact`
- `observed_runtime_qemu`
- `observed_runtime_live_hook`
- `observed_runtime_live_debugger`
- `observed_qiling_target`
- `qiling_hooked_behavior`
- `sandbox_generated`
- `mocked_behavior`
- `verified`
- `unverified`
- `blocked`

## Common Mistakes

- Passing a runtime as ready while a required API returns HTTP 500.
- Treating Qiling-only, static-only, or sandbox-only output as firmware behavior truth.
- Copying secrets from raw traces into summaries.
- Writing artifacts without `schema_version`, provenance, or sensitivity.
