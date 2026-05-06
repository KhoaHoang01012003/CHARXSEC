---
name: firmware-runtime-hooking
description: Use when Codex needs to observe live firmware service behavior during an API, browser, CLI, network, or operator workload using strace, logs, tcpdump/tshark, Frida, bpftrace, or separate Qiling instrumentation.
---

# Firmware Runtime Hooking

## Overview

Use this skill to observe real runtime behavior while the LLM or operator interacts with firmware services. Runtime hooking must prove that the capture observed the target workload; otherwise it is inconclusive evidence.

## Required Superpowers

- Use `superpowers:systematic-debugging` for HTTP 500, crash, missing dependency, auth bootstrap failure, service loop, empty capture, or inconsistent trace evidence.
- Use `superpowers:verification-before-completion` before claiming a hook captured the target behavior.
- Use `firmware-artifact-contract` before writing `hook_plan.json`, `observations.jsonl`, or redacted extracts.

## Inputs

- `runtime_profile.json`.
- `service_readiness.json`.
- Target service, process, port, API route, browser action, or CLI command.
- Workload plan from the LLM or operator.

## Workflow

1. Confirm runtime is `ready_for_pentest=true` or record why hooking is being used for root-cause debugging.
2. Define the workload and expected observation in `hook_plan.json`.
3. Detect capture lanes and record unavailable lanes as `missing_tool`.
4. For `qemu-user`, prefer `strace` on the host qemu-binfmt process plus guest logs and network capture.
5. Use logs, `tcpdump`/`tshark`, Frida, and bpftrace only when the runtime profile supports meaningful attach.
6. Treat Qiling only as a separate instrumentation lane, not runtime truth for the active emulation.
7. Record whether each capture is `host-level`, `guest-level`, network-level, app-log-level, or separate-emulator evidence.
8. Redact credentials from extracts, including `Authorization`, `Cookie`, bearer tokens, API keys, private keys, certificates, session IDs, and passwords.
9. Write high-signal extracts and `observations.jsonl`; set `behavior_claim_allowed=true` only when the live runtime workload was observed.

## Outputs

- `hook_plan.json` with `schema_version`, target service, capture lanes, workload, and expected evidence.
- Raw trace/log/pcap artifacts under ignored local evidence directories.
- Redacted extracts such as `traceback_key_lines.txt`, `http_key_events.txt`, and `syscall_summary.txt`.
- `observations.jsonl` with labels such as `observed_runtime_live_hook`, `observed_runtime_qemu`, `observed_qiling_target`, `blocked`, or `unverified`.
- `known_limitations.md` with capture blind spots and `missing_tool` records.

## Verification Gate

Hooking passes only when the transcript or extract proves the target workload ran during capture. If the capture is empty, not correlated with the workload, or only from Qiling separate instrumentation, mark it inconclusive and set `behavior_claim_allowed=false`.

## Safety

Do not commit firmware, runtime rootfs, raw logs, packet captures, credentials, cookies, tokens, private keys, certificates, or identity material. Keep raw artifacts in ignored local evidence directories and only summarize redacted extracts.

## Common Mistakes

- Calling an empty trace successful because the command exited.
- Confusing host-level QEMU process tracing with guest-level application behavior.
- Treating Qiling only as a separate instrumentation lane as proof of active runtime behavior.
- Forgetting to redact secrets before presenting extracts to the LLM.
- Continuing past HTTP 500 without systematic debugging.
