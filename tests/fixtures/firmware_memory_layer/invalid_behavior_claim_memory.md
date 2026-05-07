---
memory_schema_version: 1.0.0
memory_type: product
title: Unsupported Behavior Claim
status: draft
tags: [web, api]
applies_to:
  vendors: [example-vendor]
  models: [example-model]
  firmware_versions: [1.0.0]
  services: [web]
  runtimes: [qemu-user]
  tools: []
evidence:
  source_artifacts: [tests/fixtures/firmware_memory_layer/rootfs_profile.json]
  source_urls: []
  verified_on: 2026-05-07
  firmware_hashes: [1111111111111111111111111111111111111111111111111111111111111111]
  evidence_labels: [observed_static_artifact]
artifact_sensitivity: local_metadata
behavior_claim: true
---

# Unsupported Behavior Claim

## Use When

Use this fixture to verify behavior claims need runtime evidence.

## Durable Pattern

The API is claimed reachable, but the only evidence label is static.

## Evidence

The fixture references a rootfs profile only.

## Limits

This memory should fail validation.

## Safety

No sensitive material is included.
