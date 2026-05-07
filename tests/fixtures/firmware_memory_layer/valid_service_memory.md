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
  source_artifacts: [tests/fixtures/firmware_memory_layer/model_research.json, tests/fixtures/firmware_memory_layer/service_graph.json]
  source_urls: [https://rauc.readthedocs.io/en/latest/basic.html]
  verified_on: 2026-05-07
  firmware_hashes: [0000000000000000000000000000000000000000000000000000000000000000]
  evidence_labels: [observed_static_artifact]
artifact_sensitivity: local_metadata
---

# RAUC Update Bundle Flow

## Use When

Use this memory when the firmware manifest or rootfs profile mentions RAUC update bundles.

## Durable Pattern

RAUC bundle metadata is a useful lead for update-flow analysis. Treat it as static context until runtime update behavior is observed.

## Evidence

The fixture evidence references model research, service graph, and the public RAUC documentation URL.

## Limits

This memory does not prove that update installation is reachable at runtime.

## Safety

Keep bundle contents and device-specific update credentials out of memory files.
