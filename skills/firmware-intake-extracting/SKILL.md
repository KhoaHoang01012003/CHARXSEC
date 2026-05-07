---
name: firmware-intake-extracting
description: Use when Codex needs to identify, hash, unpack, or triage a local firmware artifact such as .bin, .raucb, .img, UBI/UBIFS, SquashFS, tar/zip vendor bundles, or nested archives before firmware emulation or pentesting.
---

# Firmware Intake Extracting

## Overview

Use this skill to turn an authorized local firmware file into a structured `firmware_manifest.json` and rootfs candidates. Never modify the original firmware file.

## Required Superpowers

- Use `superpowers:systematic-debugging` when extraction tools fail, nested formats disagree, or a rootfs candidate is not found.
- Use `superpowers:verification-before-completion` before claiming extraction succeeded.
- Use `firmware-artifact-contract` before writing `firmware_manifest.json`.

## Inputs

- Local firmware path from the user.
- Optional product, model, version, vendor URL, or expected checksum.
- Evidence root where extracted metadata and local artifacts will be written.

## Workflow

1. Confirm the firmware is authorized local input and record its absolute path.
2. Hash the input with SHA-256 before any extraction.
3. Detect format with `file`, Binwalk, archive tools, RAUC tooling, filesystem tools, and manual signatures when available.
4. Extract into a dedicated evidence/work directory outside git-tracked source unless the user explicitly chooses another path.
5. Preserve the nested extraction tree and do not overwrite earlier outputs.
6. Identify rootfs candidates, boot images, manifests, update scripts, kernels, device trees, and vendor metadata.
7. Record missing tools as `missing_tool`; do not invent extraction results.
8. Write `firmware_manifest.json`, `extraction_tree.txt`, `hashes.txt`, and `known_limitations.md`.

## Outputs

- `firmware_manifest.json` with `schema_version`, `generated_at`, `generated_by`, `source_inputs`, `warnings`, `errors`, `firmware_files`, and `rootfs_candidates`.
- `extraction_tree.txt` with the nested unpack tree.
- `hashes.txt` with SHA-256 hashes for original firmware and major extracted payloads.
- `known_limitations.md` describing missing tools, encrypted payloads, unsupported filesystems, or partial extraction.

## Verification Gate

Extraction passes only when `firmware_manifest.json` validates through `firmware-artifact-contract` and at least one rootfs candidate, boot image, or structured blocker is recorded.

If no candidate exists, write a blocker artifact and stop. Do not continue to emulation.

## Safety

Operate only on firmware and runtimes the user is authorized to test. Keep destructive probes disabled by default; record runtime modifications; prefer local evidence and redacted summaries; use exact dates and versions in vulnerability reports; do not install tools without explicit user approval.

Do not commit firmware, extracted rootfs, runtime dumps, secrets, credentials, private keys, certificates, or raw proprietary payloads. Human-facing summaries must be based on metadata and redacted extracts.

Set `behavior_claim_allowed=false` for extraction-only observations.

## Common Mistakes

- Treating a Binwalk signature as proof that extraction succeeded.
- Modifying the original firmware file during loop mount or filesystem repair.
- Extracting into a git-tracked source tree.
- Skipping hashes, which breaks later provenance.
- Claiming encrypted or unsupported payloads were analyzed.
