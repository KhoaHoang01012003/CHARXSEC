# Firmware artifacts policy

This repository intentionally does not commit Phoenix Contact firmware artifacts or extracted root filesystems.

Excluded artifacts include:

- `CHARXSEC3XXXSoftwareBundleV190.raucb`
- `work/firmware_v190_bundle/root.ext4`
- `work/firmware_v190_bundle/bootimg.vfat`
- `work/firmware_v190_rootfs/`
- runtime `/data`, `/log`, `/identity`
- runtime evidence, tokens, logs, packet captures, keys, certificates

Reason:

- Firmware and rootfs contents may be vendor copyrighted/proprietary.
- GitHub rejects regular files larger than 100 MB; this firmware bundle and extracted rootfs exceed that limit.
- Runtime evidence can contain credentials, identity material, or operational secrets.

Reproducible setup:

```powershell
.\emulation\charx_v190\bootstrap-from-bundle.cmd -BundlePath C:\path\CHARXSEC3XXXSoftwareBundleV190.raucb
```

This command extracts the authorized local bundle and builds the WSL lab at:

```text
/home/<wsl-user>/charx_labs/charx_v190
```

Start the emulation stack after bootstrap:

```powershell
.\emulation\charx_v190\charx-full-service.cmd start
```

The repo therefore remains safe to publish while still allowing another researcher with lawful access to the firmware bundle to reproduce the lab.
