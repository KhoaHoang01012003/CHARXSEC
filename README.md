# CHARX SEC-3100 V190 Research Lab

This repository contains research notes, documentation, and lab automation for studying Phoenix Contact CHARX SEC-3100 V190 firmware behavior.

The current lab is intentionally split into two tracks:

- QEMU/chroot service replay for WBM/API/service behavior.
- Qiling analysis/fuzzing/instrumentation for per-binary hooks, tracing, coverage, and debugger workflows.

Large firmware artifacts, extracted root filesystems, runtime evidence, logs, and identity/secret material are intentionally excluded from Git. This is intentional: the repository is a reproducible lab, not a redistribution channel for vendor firmware.

## Fresh Clone Bootstrap

After cloning, place an authorized copy of the V190 RAUC bundle on your machine, then run:

```powershell
.\emulation\charx_v190\bootstrap-from-bundle.cmd -BundlePath C:\path\CHARXSEC3XXXSoftwareBundleV190.raucb
```

The bootstrap script will:

- copy the bundle into the local workspace,
- extract `manifest.raucm`, `hook`, `root.ext4`, and `bootimg.vfat`,
- build the WSL lab under `/home/<wsl-user>/charx_labs/charx_v190`,
- create synthetic `/data`, `/log`, and `/identity` lab volumes,
- bootstrap Qiling unless `-SkipQiling` is passed.

To bootstrap and start the full WBM/service stack immediately:

```powershell
.\emulation\charx_v190\bootstrap-from-bundle.cmd -BundlePath C:\path\CHARXSEC3XXXSoftwareBundleV190.raucb -StartFullService
```

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

## Local Pentest Workstation

Sau khi bootstrap firmware lab, co the cai bo cong cu pentest local:

```powershell
.\emulation\charx_v190\charx-pentest.cmd bootstrap
```

Huong dan tieng Viet:

- [charx_sec_3100_local_pentest_workstation_guide_vi.md](document/charx_sec_3100_local_pentest_workstation_guide_vi.md)
- [firmware_auto_pentest_skill_suite_usage_vi.md](docs/firmware_auto_pentest_skill_suite_usage_vi.md)
