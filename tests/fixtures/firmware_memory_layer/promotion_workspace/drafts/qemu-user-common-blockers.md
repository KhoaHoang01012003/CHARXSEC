---
memory_schema_version: 1.0.0
memory_type: tool
title: QEMU User Common Blockers
status: draft
tags: [qemu-user, emulation, blocker]
applies_to:
  vendors: []
  models: []
  firmware_versions: []
  services: []
  runtimes: [qemu-user]
  tools: [qemu-user, strace]
evidence:
  source_artifacts: [tests/fixtures/firmware_memory_layer/runtime_profile.json]
  source_urls: []
  verified_on: 2026-05-07
  firmware_hashes: []
  evidence_labels: [observed_runtime_qemu]
artifact_sensitivity: local_metadata
behavior_claim: true
---

# QEMU User Common Blockers

## Use When

Use this memory when the runtime profile is `qemu-user`.

## Durable Pattern

QEMU user emulation blockers should be recorded separately from static rootfs analysis and confirmed with runtime evidence.

## Evidence

The fixture references a runtime profile with runtime evidence labels.

## Limits

This memory does not describe a specific product or vulnerability.

## Safety

Keep raw logs, pcaps, and debugger transcripts out of promoted memory.
