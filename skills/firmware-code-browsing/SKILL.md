---
name: firmware-code-browsing
description: Use when Codex needs compact firmware code, config, web route, script, or binary context from rootfs artifacts using semantic engines such as CodeQL, Semgrep, Joern, strings, readelf, or reverse-engineering queues before runtime testing.
---

# Firmware Code Browsing

## Overview

Use this skill to turn `rootfs_profile.json` and `service_graph.json` into compact, source-attributed context for LLM-guided firmware analysis. Code browsing is static analysis: it can guide hypotheses but cannot prove runtime behavior.

## Required Superpowers

- Use `superpowers:systematic-debugging` when tool output conflicts, a language is unsupported, or binary ownership is unclear.
- Use `superpowers:verification-before-completion` before claiming context is ready for LLM use.
- Use `firmware-artifact-contract` before writing `skill_context.json`, `code_browser_findings.jsonl`, or `reverse_queue.json`.

## Inputs

- `rootfs_profile.json`.
- `service_graph.json`.
- Optional `model_research.json`.
- Current hypothesis, target service, binary, web route, config, parser, or protocol.

## Workflow

1. Confirm the target component and read only the smallest rootfs/service context needed.
2. Detect available engines and record unavailable engines as `missing_tool`.
3. Use CodeQL for supported source languages only.
4. Use Semgrep for supported source, script, template, and config patterns.
5. Use Joern for C/C++/JVM code property graphs where source is present.
6. For stripped ELF or proprietary modules, use binary-map, `file`, `readelf`, `strings`, import/export/symbol analysis, and small source-attributed snippets.
7. Queue Ghidra/rizin work in `reverse_queue.json` when semantic context requires manual reverse engineering.
8. Write compact entries to `skill_context.json`; keep static observations as `behavior_claim_allowed=false`.
9. Write candidate static findings to `code_browser_findings.jsonl` only as hypotheses, not CVE claims.

## Outputs

- `skill_context.json` with `schema_version`, target components, concise source-attributed entries, and token-conscious summaries.
- `code_browser_findings.jsonl` with static candidate findings and `behavior_claim_allowed=false`.
- `reverse_queue.json` with binaries/functions/routes that need Ghidra, rizin, or debugger follow-up.
- `known_limitations.md` with unsupported languages, encrypted/minified code, missing symbols, and `missing_tool` records.

## Verification Gate

Code browsing passes only when `skill_context.json` validates, target files/components are named, snippets are small, and every static-only observation sets `behavior_claim_allowed=false`.

If context is too large for LLM use, shrink it before proceeding.

## Safety

Operate only on firmware and runtimes the user is authorized to test. Keep destructive probes disabled by default; record runtime modifications; prefer local evidence and redacted summaries; use exact dates and versions in vulnerability reports; do not install tools without explicit user approval.

Do not commit firmware, extracted rootfs, raw proprietary code, secrets, private keys, certificates, tokens, or full configs. Store raw extracts in ignored local evidence directories and expose only compact redacted summaries.

## Common Mistakes

- Treating CodeQL as a firmware binary analyzer.
- Claiming a route or parser is reachable at runtime from static output alone.
- Dumping long proprietary snippets into conversation.
- Falling back to broad grep before trying semantic tools that fit the language.
- Ignoring `missing_tool`, which hides why coverage is incomplete.
