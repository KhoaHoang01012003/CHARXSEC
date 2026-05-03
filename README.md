# CHARX SEC-3100 V190 Research Lab

This repository contains research notes, documentation, and lab automation for studying Phoenix Contact CHARX SEC-3100 V190 firmware behavior.

The current lab is intentionally split into two tracks:

- QEMU/chroot service replay for WBM/API/service behavior.
- Qiling analysis/fuzzing/instrumentation for per-binary hooks, tracing, coverage, and debugger workflows.

Large firmware artifacts, extracted root filesystems, runtime evidence, logs, and identity/secret material are intentionally excluded from Git. Keep those artifacts in the local lab workspace and regenerate evidence as needed.

## Useful Commands

Start the QEMU/chroot full service lab:

```powershell
.\emulation\charx_v190\charx-full-service.cmd start
```

Check service status:

```powershell
.\emulation\charx_v190\charx-full-service.cmd status
```

Run Qiling static map:

```powershell
.\emulation\charx_v190\charx-qiling.cmd static-map --service all
```

Run Qiling hooks against one target:

```powershell
.\emulation\charx_v190\charx-qiling.cmd run --service charx-website --timeout 10 --hooks files,sockets,syscalls,blocks,memory
```

See the detailed Qiling lab report:

```text
document/charx_sec_3100_qiling_lab_implementation_report.md
```

