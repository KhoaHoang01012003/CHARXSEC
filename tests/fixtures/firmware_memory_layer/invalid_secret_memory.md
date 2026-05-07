---
memory_schema_version: 1.0.0
memory_type: service
title: Bad Secret Memory
status: draft
tags: [http]
applies_to:
  vendors: []
  models: []
  firmware_versions: []
  services: [http]
  runtimes: []
  tools: []
evidence:
  source_artifacts: [tests/fixtures/firmware_memory_layer/service_graph.json]
  source_urls: []
  verified_on: 2026-05-07
  firmware_hashes: []
  evidence_labels: [observed_static_artifact]
artifact_sensitivity: local_sensitive
---

# Bad Secret Memory

## Use When

This intentionally bad fixture is used only by validator tests.

## Durable Pattern

Authorization: Bearer abcdef0123456789abcdef0123456789

## Evidence

The fixture references a local service graph.

## Limits

This memory should fail validation because it contains secret-like material.

## Safety

Do not promote this memory.
